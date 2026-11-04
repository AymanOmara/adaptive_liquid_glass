import AVFoundation
import Flutter
import ImageIO
import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// Presents `PHPickerViewController` for `pickGlassPhotos` and copies each
/// chosen item into `NSTemporaryDirectory()`, downscaling or converting it
/// when asked. The out-of-process picker needs no photo library permission.
final class GlassPhotosPicker: NSObject, PHPickerViewControllerDelegate,
  UIAdaptivePresentationControllerDelegate
{
  /// How `pickGlassPhotos` asked for the items to be delivered.
  struct Options {
    var maxWidth: Int?
    var maxHeight: Int?
    /// 0-100.
    var quality: Int?
    /// HEIC photos as JPEG, HEVC videos as H.264.
    var compatible = false

    init(_ args: [String: Any]) {
      maxWidth = (args["maxWidth"] as? NSNumber)?.intValue
      maxHeight = (args["maxHeight"] as? NSNumber)?.intValue
      quality = (args["imageQuality"] as? NSNumber)?.intValue
      compatible = (args["compatibleFormat"] as? NSNumber)?.boolValue ?? false
    }
  }

  /// Where the copies live; `clearPickedPhotos` deletes it.
  nonisolated static let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    .appendingPathComponent("adaptive_liquid_glass_picker", isDirectory: true)

  /// Concurrency caps: copies are I/O-bound; exports and decodes are the
  /// memory and thermal hogs.
  struct Limits {
    let loads = AsyncLimiter(limit: 3)
    let exports = AsyncLimiter(limit: 1)
    let encodes = AsyncLimiter(limit: 2)
  }

  /// The `importChannel` of this import; `cancelPhotoImport` must name it.
  let importName: String?
  private let result: FlutterResult
  private let onFinish: () -> Void
  private let options: Options
  private let onEvent: ((String, [String: Any]) -> Void)?
  private weak var pickerController: PHPickerViewController?
  private var importTask: Task<Void, Never>?
  /// Main-thread state for `progress`.
  private var throttle = ProgressThrottle()
  private var completed = 0
  private var total = 0
  private var finalSent = Set<Int>()
  /// The picker was closed (picked, dismissed or cancelled).
  private var finished = false
  /// The result was sent; later events are dropped.
  private var replied = false

  init(
    result: @escaping FlutterResult, options: Options, importName: String?,
    onEvent: ((String, [String: Any]) -> Void)?, onFinish: @escaping () -> Void
  ) {
    self.result = result
    self.options = options
    self.importName = importName
    self.onEvent = onEvent
    self.onFinish = onFinish
  }

  /// Deletes every copy made so far.
  nonisolated static func clearCopies() throws {
    try GlassPhotoCache.clear(directory)
  }

  /// Presents the picker; [onFinish] runs once the result has been sent.
  /// Returns nil (after answering [result] with an error) when there is no
  /// view controller to present from.
  static func present(
    arguments: Any?, result: @escaping FlutterResult, importName: String?,
    onEvent: ((String, [String: Any]) -> Void)?, onFinish: @escaping () -> Void
  ) -> GlassPhotosPicker? {
    let args = arguments as? [String: Any] ?? [:]
    let maxSelection = (args["maxSelection"] as? NSNumber)?.intValue ?? 1
    var config = PHPickerConfiguration()
    config.selectionLimit = max(0, maxSelection)
    config.preferredAssetRepresentationMode = .current
    config.selection = .ordered
    switch args["filter"] as? String {
    case "videos": config.filter = .videos
    case "any": config.filter = .any(of: [.images, .videos])
    default: config.filter = .images
    }
    guard let presenter = topViewController() else {
      result(FlutterError(
        code: "no_window", message: "No view controller to present the photo picker from.",
        details: nil))
      return nil
    }
    let session = GlassPhotosPicker(
      result: result, options: Options(args), importName: importName, onEvent: onEvent,
      onFinish: onFinish)
    let picker = PHPickerViewController(configuration: config)
    session.attach(picker)
    presentWhenSettled(picker, from: presenter) { session.finished }
    return session
  }

  /// Presents [controller] from [presenter], after any transition the
  /// presenter is in (UIKit can silently drop a presentation from a controller
  /// that is still being dismissed). Skipped when [skip] says so by then.
  static func presentWhenSettled(
    _ controller: UIViewController, from presenter: UIViewController,
    unless skip: @escaping () -> Bool
  ) {
    guard let coordinator = presenter.transitionCoordinator else {
      if !skip() { presenter.present(controller, animated: true) }
      return
    }
    coordinator.animate(alongsideTransition: nil) { _ in
      // Next turn: the transition is fully torn down by then.
      DispatchQueue.main.async {
        presentWhenSettled(controller, from: presenter, unless: skip)
      }
    }
  }

  /// Makes this session [picker]'s delegate, and its sheet's, so a swipe
  /// dismissal is answered too.
  func attach(_ picker: PHPickerViewController) {
    picker.delegate = self
    picker.presentationController?.delegate = self
    pickerController = picker
  }

  /// Dismisses [controller], after any transition it is in (a dismissal
  /// during the presentation would be dropped). Does nothing when
  /// [controller] is not presented.
  static func dismissWhenSettled(_ controller: UIViewController?) {
    guard let controller = controller, controller.presentingViewController != nil else { return }
    if let coordinator = controller.transitionCoordinator {
      coordinator.animate(alongsideTransition: nil) { _ in
        DispatchQueue.main.async { dismissWhenSettled(controller) }
      }
      return
    }
    controller.dismiss(animated: true)
  }

  /// The sheet was swiped away: answered like the picker's Cancel. Not
  /// called when the dismissal is the code's own.
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    if finished { return }
    finished = true
    send([])
  }

  /// Stops the import (main thread). While the picker shows, dismisses it
  /// and answers an empty, cancelled result at once; afterwards, cancels the
  /// import, which answers with the items already delivered.
  func cancel() {
    if !finished {
      // Set first, so the delegates cannot answer too. The reply does not
      // wait for the dismissal: a re-pick's present waits it out instead.
      finished = true
      Self.dismissWhenSettled(pickerController)
      send([], cancelled: true)
      return
    }
    importTask?.cancel()
  }

  /// Sends a throttled `progress` event. Every item that finishes, fails or
  /// is skipped gets exactly one [final] event, which always passes.
  @MainActor private func progress(_ index: Int, _ fraction: Double?, final: Bool = false) {
    if replied || finalSent.contains(index) { return }
    if final {
      finalSent.insert(index)
      completed += 1
    }
    guard throttle.allow(now: ProcessInfo.processInfo.systemUptime, final: final) else { return }
    var args: [String: Any] = ["index": index, "total": total, "completed": completed]
    if final {
      args["itemFraction"] = 1.0
    } else if let fraction = fraction {
      args["itemFraction"] = min(1, max(0, fraction))
    }
    onEvent?("progress", args)
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    // After a cancel, its own dismissal is already under way.
    if finished { return }
    finished = true
    if results.isEmpty {
      // At once, so a tap right after Cancel starts a new pick.
      Self.dismissWhenSettled(picker)
      send([])
      return
    }
    picker.dismiss(animated: true)
    total = results.count
    let options = options
    let limits = Limits()
    importTask = Task.detached(priority: .userInitiated) { [self] in
      // Confined to this task.
      var ordered = OrderedResults<[String: Any]>(count: results.count)
      var firstError: Error?
      await withTaskGroup(of: (Int, Outcome).self) { group in
        for (index, pick) in results.enumerated() {
          group.addTask {
            do {
              let item = try await Self.importItem(
                pick.itemProvider, index: index, options: options, limits: limits
              ) { fraction in
                await MainActor.run { self.progress(index, fraction) }
              }
              return (index, .delivered(item))
            } catch {
              // Decided when it fails: a cancel later does not hide a real failure.
              if error is CancellationError || Task.isCancelled { return (index, .interrupted) }
              return (index, .failed(error))
            }
          }
        }
        for await (index, outcome) in group {
          switch outcome {
          case .delivered(let item):
            ordered.set(index, item)
            await MainActor.run {
              self.progress(index, nil, final: true)
              self.onEvent?("itemReady", item)
            }
          case .failed(let error):
            if firstError == nil { firstError = error }
            await MainActor.run { self.progress(index, nil, final: true) }
          case .interrupted:
            break
          }
        }
      }
      let cancelled = Task.isCancelled
      let loaded = ordered.inOrder
      let failure = firstError
      await MainActor.run {
        if loaded.isEmpty, !cancelled, let error = failure {
          self.replied = true
          self.result(FlutterError(
            code: "load_failed", message: error.localizedDescription, details: nil))
          self.onFinish()
        } else {
          // After a cancel, errors are swallowed and delivered items kept.
          self.send(loaded, cancelled: cancelled)
        }
      }
    }
  }

  private enum Outcome {
    case delivered([String: Any])
    case failed(Error)
    /// Stopped by cancel: no final progress event.
    case interrupted
  }

  private func send(_ items: [[String: Any]], cancelled: Bool = false) {
    if replied { return }
    replied = true
    result(["items": items, "dropped": 0, "cancelled": cancelled])
    onFinish()
  }

  /// The share of an item's progress taken by the copy: 0.5 when a
  /// conversion follows, else the whole item (Android's `copyShareFor`).
  /// A video's codec is unknown before the copy, so a compatible video
  /// assumes an export; when none runs, the item jumps to 1 when it finishes.
  nonisolated static func copyShare(isVideo: Bool, type: UTType, options: Options) -> Double {
    let converts: Bool
    if isVideo {
      converts = options.compatible
    } else {
      converts = options.maxWidth != nil || options.maxHeight != nil || options.quality != nil
        || (options.compatible && (type.conforms(to: .heic) || type.conforms(to: .heif)))
    }
    return converts ? 0.5 : 1.0
  }

  /// Loads, copies and converts one item into its own session directory;
  /// removes that directory if it fails or is cancelled.
  nonisolated private static func importItem(
    _ provider: NSItemProvider, index: Int, options: Options, limits: Limits,
    report: @escaping @Sendable (Double?) async -> Void
  ) async throws -> [String: Any] {
    let isVideo = provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
    let type = isVideo ? UTType.movie : UTType.image
    let concrete = provider.registeredTypeIdentifiers.compactMap { UTType($0) }
      .first { $0.conforms(to: type) } ?? type
    let session = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let share = copyShare(isVideo: isVideo, type: concrete, options: options)
    do {
      let copy = try await limits.loads.run {
        try await load(provider, type: concrete, into: session) { f in
          await report(f * share)
        }
      }
      try Task.checkCancellation()
      var item = await deliver(
        copy, type: concrete, isVideo: isVideo, options: options, limits: limits
      ) { f in await report(share + f * (1 - share)) }
      try Task.checkCancellation()
      item["index"] = index
      return item
    } catch {
      try? FileManager.default.removeItem(at: session)
      throw error
    }
  }

  /// `loadFileRepresentation`, copied inside its callback, with its
  /// `Progress` observed and cancelled with the task.
  nonisolated private static func load(
    _ provider: NSItemProvider, type: UTType, into session: URL,
    report: @escaping @Sendable (Double) async -> Void
  ) async throws -> URL {
    /// The load's `Progress`, set and cancelled from different threads.
    final class Box: @unchecked Sendable {
      private let lock = NSLock()
      private var progress: Progress?
      private var cancelled = false
      private var gate = RisingFraction()
      var observation: NSKeyValueObservation?

      /// Whether [fraction] is worth a report (KVO fires from any thread).
      func shouldReport(_ fraction: Double) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return gate.allow(fraction)
      }

      func set(_ progress: Progress) {
        lock.lock()
        self.progress = progress
        let cancel = cancelled
        lock.unlock()
        if cancel { progress.cancel() }
      }

      func cancel() {
        lock.lock()
        cancelled = true
        let progress = progress
        lock.unlock()
        progress?.cancel()
      }
    }
    let box = Box()
    defer { box.observation?.invalidate() }
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        let progress = provider.loadFileRepresentation(forTypeIdentifier: type.identifier) {
          url, error in
          // The provider deletes its URL on return: copy inside this callback.
          guard let url = url else {
            continuation.resume(throwing: error ?? NSError(
              domain: "adaptive_liquid_glass", code: 1,
              userInfo: [NSLocalizedDescriptionKey: "The selected item is unavailable."]))
            return
          }
          do {
            continuation.resume(returning: try copy(url, type: type, into: session))
          } catch {
            continuation.resume(throwing: error)
          }
        }
        box.observation = progress.observe(\.fractionCompleted) { p, _ in
          let f = p.fractionCompleted
          guard box.shouldReport(f) else { return }
          Task { await report(f) }
        }
        box.set(progress)
      }
    } onCancel: {
      box.cancel()
    }
  }

  /// Copies the provider's file into [session] under a fresh name.
  nonisolated private static func copy(_ url: URL, type: UTType, into session: URL) throws -> URL {
    try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)
    let ext = url.pathExtension.isEmpty
      ? (type.preferredFilenameExtension ?? "") : url.pathExtension
    var dest = session.appendingPathComponent(UUID().uuidString)
    if !ext.isEmpty { dest.appendPathExtension(ext) }
    try GlassPhotoCache.copy(from: url, to: dest)
    return dest
  }

  /// Applies [options] to the copy at [url] and describes the result.
  /// [report] gets the conversion's fraction, 0-1.
  nonisolated private static func deliver(
    _ url: URL, type: UTType, isVideo: Bool, options: Options, limits: Limits,
    report: @escaping @Sendable (Double) async -> Void
  ) async -> [String: Any] {
    var url = url
    var item: [String: Any] = ["isVideo": isVideo]
    if isVideo {
      let asset = AVURLAsset(url: url)
      let track = try? await asset.loadTracks(withMediaType: .video).first
      if options.compatible, let track = track, await isHEVC(track) {
        // A cancel while waiting for the export slot reads as no conversion;
        // the caller's cancellation check then discards the item.
        let source = url
        if let converted = try? await limits.exports.run({
          await exportH264(asset, from: source, report: report)
        }) ?? nil {
          url = converted
        } else {
          // Delivered as HEVC; `GlassPickedPhoto.conversionFailed`.
          item["conversionFailed"] = true
        }
      }
      let delivered = url == asset.url ? asset : AVURLAsset(url: url)
      if let size = await videoSize(delivered) {
        item["width"] = size.width
        item["height"] = size.height
      }
      if let duration = try? await delivered.load(.duration), duration.isNumeric {
        item["durationMs"] = duration.seconds * 1000
      }
    } else {
      let source = url
      let encoded = try? await limits.encodes.run({
        reencode(source, type: type, options: options)
      }) ?? nil
      await report(1)
      if let encoded = encoded {
        url = encoded
      } else if options.compatible && (type.conforms(to: .heic) || type.conforms(to: .heif)) {
        item["conversionFailed"] = true
      }
      if let size = imageSize(url) {
        item["width"] = size.width
        item["height"] = size.height
      }
    }
    item["path"] = url.path
    let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
      ?? type.preferredMIMEType
    if let mime = mime { item["mimeType"] = mime }
    return item
  }

  // MARK: Photos

  /// Writes a downscaled or converted copy of the photo at [url] and
  /// deletes the original; nil when [options] leave it as it is (or
  /// ImageIO cannot write it).
  nonisolated private static func reencode(_ url: URL, type: UTType, options: Options) -> URL? {
    if type.conforms(to: .gif) { return nil }
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let size = imageSize(url)
    else { return nil }
    let isHEIF = type.conforms(to: .heic) || type.conforms(to: .heif)
    let lossy = isHEIF || type.conforms(to: .jpeg)
    let scale = min(
      1,
      options.maxWidth.map { Double($0) / Double(size.width) } ?? 1,
      options.maxHeight.map { Double($0) / Double(size.height) } ?? 1)
    let resize = scale < 1
    let convert = options.compatible && isHEIF
    guard resize || convert || (options.quality != nil && lossy) else { return nil }
    let longest = Double(max(size.width, size.height))
    let thumbOptions: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      // Bakes the EXIF orientation into the pixels.
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: max(1, Int((longest * scale).rounded())),
    ]
    guard
      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary)
    else { return nil }
    let keeps = !convert && (isHEIF || type.conforms(to: .jpeg) || type.conforms(to: .png))
    var props: [CFString: Any] = [:]
    if let quality = options.quality {
      props[kCGImageDestinationLossyCompressionQuality] = Double(quality) / 100
    }
    for target in keeps ? [type, .jpeg] : [.jpeg] {
      let dest = url.deletingPathExtension()
        .appendingPathExtension("out." + (target.preferredFilenameExtension ?? "jpg"))
      guard
        let out = CGImageDestinationCreateWithURL(
          dest as CFURL, target.identifier as CFString, 1, nil)
      else { continue }
      CGImageDestinationAddImage(out, image, props as CFDictionary)
      if CGImageDestinationFinalize(out) {
        try? FileManager.default.removeItem(at: url)
        return dest
      }
      try? FileManager.default.removeItem(at: dest)
    }
    return nil
  }

  /// The pixel size from the image header, without decoding the image.
  nonisolated private static func imageSize(_ url: URL) -> (width: Int, height: Int)? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let w = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
      let h = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue
    else { return nil }
    // EXIF orientations 5-8 rotate by 90 degrees: report the upright size.
    let orientation = (props[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
    return orientation >= 5 ? (h, w) : (w, h)
  }

  // MARK: Videos

  nonisolated private static func isHEVC(_ track: AVAssetTrack) async -> Bool {
    guard let formats = try? await track.load(.formatDescriptions) else { return false }
    return formats.contains { CMFormatDescriptionGetMediaSubType($0) == kCMVideoCodecType_HEVC }
  }

  /// Exports [asset] as H.264 `.mp4` and deletes the original at [url];
  /// nil (keeping the original) when the export fails or is cancelled.
  /// [report] gets the export's fraction about every 100 ms.
  nonisolated private static func exportH264(
    _ asset: AVURLAsset, from url: URL, report: @escaping @Sendable (Double) async -> Void
  ) async -> URL? {
    if Task.isCancelled { return nil }
    // HighestQuality is H.264; the HEVC presets are separate.
    guard
      let session = AVAssetExportSession(
        asset: asset, presetName: AVAssetExportPresetHighestQuality)
    else { return nil }
    let dest = url.deletingPathExtension().appendingPathExtension("out.mp4")
    session.outputURL = dest
    session.outputFileType = .mp4
    session.shouldOptimizeForNetworkUse = true
    let poll = Task {
      while !Task.isCancelled, session.status == .waiting || session.status == .exporting
        || session.status == .unknown {
        await report(Double(session.progress))
        try? await Task.sleep(nanoseconds: 100_000_000)
      }
    }
    await withTaskCancellationHandler {
      await withCheckedContinuation { done in
        session.exportAsynchronously { done.resume() }
        // A cancel just before the export started ran `onCancel` too early.
        if Task.isCancelled { session.cancelExport() }
      }
    } onCancel: {
      session.cancelExport()
    }
    poll.cancel()
    guard session.status == .completed else {
      try? FileManager.default.removeItem(at: dest)
      return nil
    }
    try? FileManager.default.removeItem(at: url)
    return dest
  }

  /// The upright pixel size of the first video track.
  nonisolated private static func videoSize(_ asset: AVURLAsset) async -> (width: Int, height: Int)? {
    guard let track = try? await asset.loadTracks(withMediaType: .video).first,
      let loaded = try? await track.load(.naturalSize, .preferredTransform)
    else { return nil }
    let size = loaded.0.applying(loaded.1)
    let w = Int(abs(size.width).rounded())
    let h = Int(abs(size.height).rounded())
    return w > 0 && h > 0 ? (w, h) : nil
  }

  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window =
      scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
      ?? scenes.flatMap { $0.windows }.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController, !presented.isBeingDismissed {
      top = presented
    }
    return top
  }
}

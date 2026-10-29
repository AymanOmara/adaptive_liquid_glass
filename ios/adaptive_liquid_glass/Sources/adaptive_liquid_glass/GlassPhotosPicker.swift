import AVFoundation
import Flutter
import ImageIO
import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// Presents `PHPickerViewController` for `pickGlassPhotos` and copies each
/// chosen item into `NSTemporaryDirectory()`, downscaling or converting it
/// when asked. The out-of-process picker needs no photo library permission.
final class GlassPhotosPicker: NSObject, PHPickerViewControllerDelegate {
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
  static let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    .appendingPathComponent("adaptive_liquid_glass_picker", isDirectory: true)

  private let result: FlutterResult
  private let onFinish: () -> Void
  private let options: Options
  private let onItemReady: (([String: Any]) -> Void)?
  private var finished = false

  private init(
    result: @escaping FlutterResult, options: Options,
    onItemReady: (([String: Any]) -> Void)?, onFinish: @escaping () -> Void
  ) {
    self.result = result
    self.options = options
    self.onItemReady = onItemReady
    self.onFinish = onFinish
  }

  /// Deletes every copy made so far.
  static func clearCopies() throws {
    try GlassPhotoCache.clear(directory)
  }

  /// Presents the picker; [onFinish] runs once the result has been sent.
  /// Returns nil (after answering [result] with an error) when there is no
  /// view controller to present from.
  static func present(
    arguments: Any?, result: @escaping FlutterResult,
    onItemReady: (([String: Any]) -> Void)?, onFinish: @escaping () -> Void
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
      result: result, options: Options(args), onItemReady: onItemReady, onFinish: onFinish)
    let picker = PHPickerViewController(configuration: config)
    picker.delegate = session
    presenter.present(picker, animated: true)
    return session
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    if finished { return }
    finished = true
    if results.isEmpty {
      send([])
      return
    }
    // Import one item at a time. Unlimited selections must not start dozens
    // of full-resolution decodes and video exports concurrently.
    let options = options
    Task.detached(priority: .userInitiated) {
      var loaded: [[String: Any]] = []
      var firstError: Error?
      for pick in results {
        let provider = pick.itemProvider
        let isVideo = provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
        let type = isVideo ? UTType.movie : UTType.image
        let concrete = provider.registeredTypeIdentifiers.compactMap { UTType($0) }
          .first { $0.conforms(to: type) } ?? type
        do {
          let copy: URL = try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: concrete.identifier) { url, error in
              // The provider deletes its URL on return: copy inside this callback.
              guard let url = url else {
                continuation.resume(throwing: error ?? NSError(
                  domain: "adaptive_liquid_glass", code: 1,
                  userInfo: [NSLocalizedDescriptionKey: "The selected item is unavailable."]))
                return
              }
              do {
                continuation.resume(returning: try Self.copy(url, type: concrete))
              } catch {
                continuation.resume(throwing: error)
              }
            }
          }
          let item = await Self.deliver(copy, type: concrete, isVideo: isVideo, options: options)
          loaded.append(item)
          await MainActor.run { self.onItemReady?(item) }
        } catch {
          if firstError == nil { firstError = error }
        }
      }
      await MainActor.run {
        if loaded.isEmpty, let error = firstError {
          self.result(FlutterError(
            code: "load_failed", message: error.localizedDescription, details: nil))
          self.onFinish()
        } else {
          self.send(loaded)
        }
      }
    }
  }

  private func send(_ items: [[String: Any]]) {
    result(items)
    onFinish()
  }

  /// Copies the provider's file into [directory] under a fresh name.
  private static func copy(_ url: URL, type: UTType) throws -> URL {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let ext = url.pathExtension.isEmpty
      ? (type.preferredFilenameExtension ?? "") : url.pathExtension
    var dest = directory.appendingPathComponent(UUID().uuidString)
    if !ext.isEmpty { dest.appendPathExtension(ext) }
    try GlassPhotoCache.copy(from: url, to: dest)
    return dest
  }

  /// Applies [options] to the copy at [url] and describes the result.
  private static func deliver(
    _ url: URL, type: UTType, isVideo: Bool, options: Options
  ) async -> [String: Any] {
    var url = url
    var item: [String: Any] = ["isVideo": isVideo]
    if isVideo {
      let asset = AVURLAsset(url: url)
      let track = try? await asset.loadTracks(withMediaType: .video).first
      if options.compatible, let track = track, await isHEVC(track) {
        if let converted = await exportH264(asset, from: url) {
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
      if let encoded = reencode(url, type: type, options: options) {
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
  private static func reencode(_ url: URL, type: UTType, options: Options) -> URL? {
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
  private static func imageSize(_ url: URL) -> (width: Int, height: Int)? {
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

  private static func isHEVC(_ track: AVAssetTrack) async -> Bool {
    guard let formats = try? await track.load(.formatDescriptions) else { return false }
    return formats.contains { CMFormatDescriptionGetMediaSubType($0) == kCMVideoCodecType_HEVC }
  }

  /// Exports [asset] as H.264 `.mp4` and deletes the original at [url];
  /// nil (keeping the original) when the export fails.
  private static func exportH264(_ asset: AVURLAsset, from url: URL) async -> URL? {
    // HighestQuality is H.264; the HEVC presets are separate.
    guard
      let session = AVAssetExportSession(
        asset: asset, presetName: AVAssetExportPresetHighestQuality)
    else { return nil }
    let dest = url.deletingPathExtension().appendingPathExtension("out.mp4")
    session.outputURL = dest
    session.outputFileType = .mp4
    session.shouldOptimizeForNetworkUse = true
    await withCheckedContinuation { done in
      session.exportAsynchronously { done.resume() }
    }
    guard session.status == .completed else {
      try? FileManager.default.removeItem(at: dest)
      return nil
    }
    try? FileManager.default.removeItem(at: url)
    return dest
  }

  /// The upright pixel size of the first video track.
  private static func videoSize(_ asset: AVURLAsset) async -> (width: Int, height: Int)? {
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

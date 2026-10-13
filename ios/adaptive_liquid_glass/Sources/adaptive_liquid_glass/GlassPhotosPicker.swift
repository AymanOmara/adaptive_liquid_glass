import Flutter
import ImageIO
import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// Presents `PHPickerViewController` for `pickGlassPhotos` and copies each
/// chosen item into `NSTemporaryDirectory()`. The out-of-process picker
/// needs no photo library permission.
final class GlassPhotosPicker: NSObject, PHPickerViewControllerDelegate {
  private let result: FlutterResult
  private let onFinish: () -> Void
  private var finished = false

  private init(result: @escaping FlutterResult, onFinish: @escaping () -> Void) {
    self.result = result
    self.onFinish = onFinish
  }

  /// Presents the picker; [onFinish] runs once the result has been sent.
  /// Returns nil (after answering [result] with an error) when there is no
  /// view controller to present from.
  static func present(
    arguments: Any?, result: @escaping FlutterResult, onFinish: @escaping () -> Void
  ) -> GlassPhotosPicker? {
    let args = arguments as? [String: Any] ?? [:]
    let maxSelection = (args["maxSelection"] as? NSNumber)?.intValue ?? 1
    var config = PHPickerConfiguration()
    config.selectionLimit = max(0, maxSelection)
    config.preferredAssetRepresentationMode = .current
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
    let session = GlassPhotosPicker(result: result, onFinish: onFinish)
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
    let group = DispatchGroup()
    let lock = NSLock()
    var items = [[String: Any]?](repeating: nil, count: results.count)
    var firstError: Error?
    for (index, pick) in results.enumerated() {
      let provider = pick.itemProvider
      let isVideo = provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
      let type = isVideo ? UTType.movie : UTType.image
      // The concrete type (e.g. public.heic) names the extension and MIME.
      let concrete =
        provider.registeredTypeIdentifiers.compactMap { UTType($0) }
        .first { $0.conforms(to: type) } ?? type
      group.enter()
      provider.loadFileRepresentation(forTypeIdentifier: concrete.identifier) { url, error in
        defer { group.leave() }
        // The provider deletes `url` when this block returns: copy now.
        guard let url = url else {
          lock.lock()
          if firstError == nil { firstError = error }
          lock.unlock()
          return
        }
        do {
          let item = try Self.copy(url, type: concrete, isVideo: isVideo)
          lock.lock()
          items[index] = item
          lock.unlock()
        } catch {
          lock.lock()
          if firstError == nil { firstError = error }
          lock.unlock()
        }
      }
    }
    group.notify(queue: .main) {
      let loaded = items.compactMap { $0 }
      if loaded.isEmpty, let error = firstError {
        self.result(FlutterError(
          code: "load_failed", message: error.localizedDescription, details: nil))
        self.onFinish()
      } else {
        self.send(loaded)
      }
    }
  }

  private func send(_ items: [[String: Any]]) {
    result(items)
    onFinish()
  }

  private static func copy(_ url: URL, type: UTType, isVideo: Bool) throws -> [String: Any] {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent("adaptive_liquid_glass_picker", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let ext = url.pathExtension.isEmpty
      ? (type.preferredFilenameExtension ?? "") : url.pathExtension
    var dest = dir.appendingPathComponent(UUID().uuidString)
    if !ext.isEmpty { dest.appendPathExtension(ext) }
    try FileManager.default.copyItem(at: url, to: dest)
    var item: [String: Any] = ["path": dest.path, "isVideo": isVideo]
    let mime = UTType(filenameExtension: ext)?.preferredMIMEType ?? type.preferredMIMEType
    if let mime = mime { item["mimeType"] = mime }
    if !isVideo, let size = imageSize(dest) {
      item["width"] = size.width
      item["height"] = size.height
    }
    return item
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

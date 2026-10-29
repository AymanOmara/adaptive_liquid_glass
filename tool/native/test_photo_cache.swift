// Run with the production GlassPhotoCache.swift as a second input to swiftc.
import Foundation

@main
enum PhotoCacheTests {
  final class DeniedFiles: FileManager, @unchecked Sendable {
    override func removeItem(at URL: URL) throws {
      throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError)
    }
  }

  final class InterruptedCopy: FileManager, @unchecked Sendable {
    override func copyItem(at source: URL, to destination: URL) throws {
      try Data("partial".utf8).write(to: destination)
      throw NSError(domain: "photo-cache-test", code: 17)
    }
  }

  static func main() throws {
    let files = FileManager.default
    let root = files.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? files.removeItem(at: root) }
    let nested = root.appendingPathComponent("session", isDirectory: true)
    try files.createDirectory(at: nested, withIntermediateDirectories: true)
    let source = nested.appendingPathComponent("photo.jpg")
    let destination = nested.appendingPathComponent("copied.jpg")
    try Data("copy".utf8).write(to: source)
    do {
      try GlassPhotoCache.copy(from: source, to: destination, using: InterruptedCopy())
      fatalError("Interrupted copy must fail")
    } catch let error as NSError {
      precondition(error.domain == "photo-cache-test" && error.code == 17)
      precondition(!files.fileExists(atPath: destination.path))
      let original = try Data(contentsOf: source)
      precondition(original == Data("copy".utf8))
    }
    try GlassPhotoCache.copy(from: source, to: destination)
    let copied = try Data(contentsOf: destination)
    precondition(copied == Data("copy".utf8))
    try GlassPhotoCache.clear(root)
    precondition(!files.fileExists(atPath: root.path))
    try GlassPhotoCache.clear(root) // Missing cache succeeds.
    do {
      try GlassPhotoCache.clear(root, using: DeniedFiles())
      fatalError("Permission failure must propagate")
    } catch let error as NSError {
      precondition(error.code == NSFileWriteNoPermissionError)
    }
    // A previous failure does not block a subsequent successful cleanup.
    try files.createDirectory(at: root, withIntermediateDirectories: true)
    try GlassPhotoCache.clear(root)
    precondition(!files.fileExists(atPath: root.path))
    print("6 photo-cache filesystem checks passed")
  }
}

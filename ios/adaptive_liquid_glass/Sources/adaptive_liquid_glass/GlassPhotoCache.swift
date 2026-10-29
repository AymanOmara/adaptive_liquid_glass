import Foundation

enum GlassPhotoCache {
  static func copy(from source: URL, to destination: URL, using files: FileManager = .default) throws {
    do {
      try files.copyItem(at: source, to: destination)
    } catch {
      // A failed copy may already have created a partial destination.
      try? files.removeItem(at: destination)
      throw error
    }
  }

  /// A missing cache is already clean; other failures must reach the caller.
  static func clear(_ directory: URL, using files: FileManager = .default) throws {
    do {
      try files.removeItem(at: directory)
    } catch let error as NSError {
      guard error.domain == NSCocoaErrorDomain,
        error.code == NSFileNoSuchFileError else { throw error }
    }
  }
}

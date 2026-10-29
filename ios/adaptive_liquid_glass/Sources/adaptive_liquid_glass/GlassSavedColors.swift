import Foundation

/// App-local palette storage, separate from UIKit's private saved colours.
enum GlassSavedColors {
  private static func fileURL() throws -> URL {
    let folder = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask,
      appropriateFor: nil, create: true)
      .appendingPathComponent("adaptive_liquid_glass", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder.appendingPathComponent("saved_colors.json")
  }

  static func load() throws -> [Int64]? {
    let url = try fileURL()
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return try JSONDecoder().decode([Int64].self, from: Data(contentsOf: url))
  }

  static func save(_ colors: [Int64]) throws {
    try JSONEncoder().encode(colors).write(to: fileURL(), options: .atomic)
  }
}

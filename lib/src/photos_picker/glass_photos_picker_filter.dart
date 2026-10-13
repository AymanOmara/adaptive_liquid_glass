/// What the system photo picker offers: SwiftUI's `PHPickerFilter`, as
/// passed to `PhotosPicker(selection:matching:)`.
enum GlassPhotosPickerFilter {
  /// Photos only (`PHPickerFilter.images`; `image/*` on Android).
  images,

  /// Videos only (`PHPickerFilter.videos`; `video/*` on Android).
  videos,

  /// Photos and videos (`.any(of: [.images, .videos])`).
  any,
}

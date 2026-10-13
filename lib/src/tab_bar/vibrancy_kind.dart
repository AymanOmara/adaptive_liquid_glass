/// What a [VibrantBlend] draws over shader glass, each fitted per pixel to
/// iOS 26.4's tab bar over a photo.
enum VibrancyKind {
  /// An untinted label: the glass's hue at the glyph's lightness.
  label,

  /// The selected tint: each channel moves by part of the glass's change.
  tint,

  /// The selected pill: the glass darkened, more where it is darker.
  pill,
}

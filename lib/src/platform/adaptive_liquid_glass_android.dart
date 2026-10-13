/// The Dart half of the Android implementation.
///
/// Android renders Material 3 surfaces in Dart. The Kotlin plugin
/// (`AdaptiveLiquidGlassPlugin`) only answers `pickPhotos` on the method
/// channel; `GlassPlatform` still reads nothing from it off iOS. Not
/// exported.
abstract final class AdaptiveLiquidGlassAndroid {
  /// Called by the generated plugin registrant; nothing to register.
  static void registerWith() {}
}

/// The Dart half of the Android implementation.
///
/// Android renders Material 3 surfaces in Dart. The Kotlin plugin
/// (`AdaptiveLiquidGlassPlugin`) hosts the photo picker and stores the
/// colour palette; `GlassPlatform` reads no environment facts off iOS. Not
/// exported.
abstract final class AdaptiveLiquidGlassAndroid {
  /// Called by the generated plugin registrant; nothing to register.
  static void registerWith() {}
}

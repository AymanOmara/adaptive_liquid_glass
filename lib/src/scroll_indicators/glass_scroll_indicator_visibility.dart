/// Whether a scrollable shows its indicators, as SwiftUI's
/// `.scrollIndicators(_:)` visibility.
///
/// On iOS (and Android) [automatic] and [visible] behave alike: the
/// indicator shows while the content scrolls and fades out after. With a
/// mouse or trackpad (desktop, web), [visible] keeps it shown, as on
/// macOS.
enum GlassScrollIndicatorVisibility {
  /// The platform's default: shown while scrolling.
  automatic,

  /// Shown while scrolling; kept shown on pointer platforms.
  visible,

  /// Hidden. SwiftUI may still show it where the platform requires one;
  /// no platform this package targets does.
  hidden,

  /// Never shown.
  never;

  /// Whether this visibility draws an indicator at all.
  bool get shows => this == automatic || this == visible;
}

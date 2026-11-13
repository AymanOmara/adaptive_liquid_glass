/// How a glass navigation bar blurs the content scrolled under it.
///
/// ```dart
/// GlassNavigationBar(
///   title: const Text('Inbox'),
///   scrollEdgeStyle: GlassScrollEdgeStyle.progressive,
/// )
/// ```
///
/// [uniform] and [progressive] fade the page background in towards the top;
/// [hard] cuts it off sharply and [hidden] draws nothing. None blurs on the
/// native path, where the page's glass is UIKit views Flutter cannot blur
/// in place.
enum GlassScrollEdgeStyle {
  /// One even blur under the bar whose lower edge the fade hides.
  uniform,

  /// A graduated blur: strongest at the top, easing to sharp further down,
  /// like iOS 26's soft scroll edge. Needs Impeller's shader filters; falls
  /// back to [uniform] without them (Skia, web) and until its shader has
  /// loaded.
  progressive,

  /// A sharp edge, as SwiftUI's `scrollEdgeEffectStyle(.hard)`: an even blur
  /// and background tint under the bar with a crisp lower boundary and no
  /// fade.
  hard,

  /// No scroll edge effect, as `scrollEdgeEffectStyle(.hidden)`: content
  /// scrolls under the bar untouched.
  hidden,
}

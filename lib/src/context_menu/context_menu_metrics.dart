import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

/// iOS 26's context menu, measured from UIKit's UIContextMenuInteraction
/// (what SwiftUI's `.contextMenu` rides on) on iPhone 17 Pro / iOS 26.4,
/// opened programmatically in the reference harness (`-controls
/// contextmenuuikit`, `…left`, `…wide`; "components" → "context_menu" in
/// tool/reference/controls.json). Synthetic touches still do not open
/// SwiftUI's own. The menu itself is the measured glass menu
/// (`MenuMetrics`). The page behind is dimmed (`GlassColors
/// .contextMenuBarrier`) but not blurred: over 100-pt black and white
/// stripes its edges stay one pixel sharp (`-controls
/// contextmenuuikitstripes`).
abstract final class ContextMenuMetrics {
  /// The gap between the lifted item and the menu (measured: 16 under a
  /// 200 x 120 and a 360 x 80 card).
  static const double gap = 16;

  /// How much the lifted item grows (measured: a 200 x 120 card lifts to
  /// 226 x 135.7), unless that would bring it closer than [margin] to the
  /// screen's sides (a 360-pt card lifts to 369, 1.024).
  static const double lift = 1.13;

  /// The closest the lifted item and the menu come to the screen's sides
  /// (measured: both clamp to 16 near the leading edge).
  static const double margin = 16;

  /// Where an item at [rect] sits lifted on a screen of [size]: grown by
  /// [lift] about its centre, less when it would not fit between the
  /// [margin]s, then shifted inside them, as UIKit does.
  static Rect lifted(Rect rect, Size size) {
    final room = size.width - 2 * margin;
    final scale = rect.width <= 0
        ? lift
        : math.max(1.0, math.min(lift, room / rect.width));
    final w = rect.width * scale;
    final h = rect.height * scale;
    final left = w >= room
        ? (size.width - w) / 2
        : (rect.center.dx - w / 2).clamp(margin, size.width - margin - w);
    return Rect.fromLTWH(left, rect.center.dy - h / 2, w, h);
  }
}

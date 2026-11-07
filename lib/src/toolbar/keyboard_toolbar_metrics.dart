import 'package:flutter/widgets.dart';

import '../button/glass_button_metrics.dart';
import 'toolbar_metrics.dart';

/// iOS 26's keyboard toolbar (`ToolbarItemGroup(placement: .keyboard)`),
/// measured from SwiftUI on iPhone 17 Pro / iOS 26.4 (`-controls
/// keyboardtoolbar` / `keyboardtoolbardark`, 2026-11-08): 48-pt capsules
/// 16 pt in from the sides, resting on the keyboard; two icons make a
/// 104-pt capsule, a lone "Done" a 72.33-pt one.
abstract final class KeyboardToolbarMetrics {
  /// The capsules' height.
  static const double height = 48;

  /// The capsules' inset from the screen's sides.
  static const double edgeInset = 16;

  /// The capsules' bottom edge above the keyboard's top.
  static const double gap = 0;

  /// A lone item: a 48-pt circle, or "Done" in a 72.33-pt capsule.
  static const GlassButtonMetrics single = ToolbarMetrics.single;

  /// An item in a group: two items make a 104-pt capsule.
  static const GlassButtonMetrics grouped = GlassButtonMetrics(
    height: height,
    padding: 14,
    fontSize: 17,
    iconSize: 26,
    iconGap: 6,
    iconOnlyHeight: height,
    iconOnlyExtraWidth: 104 / 2 - height,
    cornerRadius: 12,
  );

  /// The Material path's bar height (a Material toolbar row).
  static const double materialHeight = 48;

  /// Finds the Material path's bar in tests.
  static const Key materialBarKey = ValueKey('GlassKeyboardToolbar.material');
}

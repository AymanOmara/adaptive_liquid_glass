/// Where iOS 26 floats its tab bar and its bottom accessory, measured from
/// SwiftUI on iPhone 17 Pro / iOS 26.4 (`tool/reference/controls.json`,
/// "components" → "accessory"; tested against it).
abstract final class ScaffoldMetrics {
  /// The tab bar's bottom edge above the screen's on a phone with a home
  /// indicator (Kept: 21 over a 34 safe area).
  static const double tabBarBottom = 21;

  /// The same gap on a screen without a home indicator.
  static const double tabBarBottomFlat = 8;

  /// The gap between the bottom accessory and the tab bar.
  static const double accessoryGap = 8;

  /// The bottom accessory's height.
  static const double accessoryHeight = 48;

  /// The bottom accessory's inset from the screen's sides.
  static const double accessoryInset = 21;

  /// With the tab bar minimized, the accessory drops into the bar's row
  /// beside the circle: its start and end from the screen's sides (iOS
  /// 26.4, `tabbarminimizeacc`: 84 and 30 pt, 48 pt tall, centred on the
  /// bar).
  static const double accessoryMinimizedStart = 84;

  /// See [accessoryMinimizedStart].
  static const double accessoryMinimizedEnd = 30;

  /// How long the accessory takes to move with the minimizing bar (the
  /// bar's 0.4 s spring, settled).
  static const Duration accessoryMinimizeDuration = Duration(milliseconds: 450);

  /// The floating action button's margin from the screen's end and from
  /// the bars below it (Material 3's 16; iOS has no such button).
  static const double floatingActionButtonMargin = 16;

  /// The tab bar's scroll edge (TabBarScrollEdge): how far above the
  /// screen's bottom it starts.
  static const double tabBarEdgeHeight = 115;

  /// The fade's opacity at [tabBarEdgeStops] (top to bottom), from iOS
  /// 26.4's text ink at 115, 99, 88, 42, 32, 25 and 0 pt above the bottom.
  static const List<double> tabBarEdgeAlphas = [
    0,
    0.06,
    0.14,
    0.3,
    0.64,
    0.74,
    0.88,
  ];

  /// See [tabBarEdgeAlphas].
  static const List<double> tabBarEdgeStops = [
    0,
    16 / 115,
    27 / 115,
    73 / 115,
    83 / 115,
    90 / 115,
    1,
  ];
}

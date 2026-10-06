/// iOS 26's context menu. Not measured: the simulator's synthetic touches
/// do not open SwiftUI's `.contextMenu`, so these follow the system's
/// look; the menu itself is the measured glass menu (`MenuMetrics`).
abstract final class ContextMenuMetrics {
  /// The blur of the page behind the lifted item.
  static const double blur = 16;

  /// The gap between the lifted item and the menu.
  static const double gap = 12;

  /// How much the lifted item grows.
  static const double lift = 1.03;

  /// The closest the menu comes to the screen's edges.
  static const double margin = 16;
}

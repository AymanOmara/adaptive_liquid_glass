/// The keyboard focus ring drawn around focused glass controls (iPad and
/// Mac with a hardware keyboard). Estimated from iPadOS 26 screenshots,
/// not measured.
abstract final class FocusRingMetrics {
  /// The ring's stroke width.
  static const double width = 3;

  /// The gap between the control's edge and the ring's inner edge.
  static const double gap = 2;
}

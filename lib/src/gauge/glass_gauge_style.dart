/// Which form [GlassGauge] draws.
enum GlassGaugeStyle {
  /// SwiftUI's default `.linearCapacity`: a capsule track filled to
  /// the value.
  linearCapacity,

  /// `.accessoryCircular`: an open ring (gap at the bottom) with a dot
  /// marking the value.
  accessoryCircular,

  /// `.accessoryCircularCapacity`: a closed ring filled to the value.
  accessoryCircularCapacity,
}

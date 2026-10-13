/// iOS 26's pull to refresh, estimated from SwiftUI's `.refreshable` in
/// Mail (iOS 26.4); only the snap-back spring is measured.
abstract final class RefreshMetrics {
  /// The overscroll that arms the refresh. Estimated.
  static const double triggerDistance = 65;

  /// The room the indicator keeps while refreshing. Estimated.
  static const double indicatorExtent = 60;

  /// The glass disk's diameter behind the spinner. Estimated.
  static const double diskSize = 36;

  /// The spinner's / ring's diameter. Estimated.
  static const double spinnerSize = 20;

  /// SwiftUI spring response for the indicator's snap-back once the
  /// refresh ends. Measured from SwiftUI's `.refreshable` on iOS 26.4 (the
  /// list's return from its ~60 pt hold, tool/fidelity/component_motion.py
  /// --last): median 0.47 over four takes (0.46-0.51).
  static const double snapResponse = 0.47;

  /// SwiftUI damping fraction for the snap-back (fits 0.76-0.78).
  static const double snapDamping = 0.77;

  /// The smallest scale the indicator grows from while pulling.
  static const double minScale = 0.3;
}

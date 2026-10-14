/// iOS 26's pull to refresh, from SwiftUI's `.refreshable` (iOS 26.4): the
/// hold, its settle and the snap-back are measured; the rest estimated.
abstract final class RefreshMetrics {
  /// The overscroll that arms the refresh. Estimated.
  static const double triggerDistance = 65;

  /// The room the indicator keeps while refreshing: the content is held
  /// this far down and the spinner centred in it. Measured from SwiftUI's
  /// `.refreshable` on iOS 26.4 (a plain List held 60.3 pt below its rest,
  /// spinner centred 30 pt below the list's top inset, two takes).
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

  /// SwiftUI spring response for the content easing from the released
  /// pull into the hold. Fitted to SwiftUI's `.refreshable` on iOS 26.4
  /// (UIScrollView's bounce into its refresh inset, two takes jointly,
  /// rms 1.9 pt over ~130 pt).
  static const double holdResponse = 0.30;

  /// SwiftUI damping fraction for the settle into the hold (overdamped:
  /// a fast start and a long tail, as UIScrollView's bounce).
  static const double holdDamping = 1.43;

  /// The smallest scale the indicator grows from while pulling.
  static const double minScale = 0.3;
}

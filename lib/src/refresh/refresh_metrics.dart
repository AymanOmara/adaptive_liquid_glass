/// iOS 26's pull to refresh, estimated from SwiftUI's `.refreshable` in
/// Mail (iOS 26.4); none of these are measured yet.
abstract final class RefreshMetrics {
  /// The overscroll that arms the refresh. Estimated.
  static const double triggerDistance = 65;

  /// The room the indicator keeps while refreshing. Estimated.
  static const double indicatorExtent = 60;

  /// The glass disk's diameter behind the spinner. Estimated.
  static const double diskSize = 36;

  /// The spinner's / ring's diameter. Estimated.
  static const double spinnerSize = 20;

  /// SwiftUI spring response for the indicator's snap-back. Estimated.
  static const double snapResponse = 0.35;

  /// SwiftUI damping fraction for the snap-back. Estimated.
  static const double snapDamping = 0.8;

  /// The smallest scale the indicator grows from while pulling.
  static const double minScale = 0.3;
}

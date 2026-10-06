/// iOS 26's progress indicator, estimated from SwiftUI's `ProgressView`
/// (UIKit/HIG defaults); not measured.
abstract final class ProgressMetrics {
  /// The linear track's height, a capsule.
  static const double linearHeight = 6;

  /// The gap between the glass track and the fill.
  static const double fillInset = 1;

  /// The ring's and the spinner's diameter.
  static const double circularSize = 20;

  /// The ring's stroke.
  static const double ringStroke = 3;

  /// The moving segment's share of the track.
  static const double indeterminateFraction = 0.3;

  /// The moving segment's lap across the track.
  static const Duration indeterminatePeriod = Duration(milliseconds: 1200);

  /// The fill easing to a new value.
  static const Duration valueAnimation = Duration(milliseconds: 250);
}

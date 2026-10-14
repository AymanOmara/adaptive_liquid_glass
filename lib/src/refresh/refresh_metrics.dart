/// iOS 26's pull to refresh, measured from SwiftUI's `.refreshable` on
/// iOS 26.4 (`-controls refreshmotion`, frame dumps of `idb ui swipe
/// --delta 5` pulls; tool/fidelity/record_component_motion.sh).
abstract final class RefreshMetrics {
  /// The overscroll that starts the refresh, while the finger is still
  /// down. Measured: pulls whose list moved 146.7, 155.6, 162.0 and 170.6
  /// pt did not refresh; 174.7 and more did, the spinner's last spoke
  /// showing at ~175 pt in every take.
  static const double triggerDistance = 173;

  /// The finger's travel past the top that starts the refresh, whichever
  /// of it and [triggerDistance] comes first. Measured: UIScrollView's
  /// rubber band reaches 173 pt after about 315 pt of finger travel (305
  /// did not refresh, 320 did). `GlassRefreshScrollPhysics` reaches
  /// [triggerDistance] there; this catches scrollables with other physics
  /// (Flutter's bouncing friction needs over 400 for the same overscroll).
  static const double triggerTravel = 315;

  /// UIScrollView's rubber band under a pull from the top, the content's
  /// travel per finger travel as the pull starts. Fitted to SwiftUI's
  /// List on iOS 26.4 with [rubberBandReach] (`-controls refreshmotion`,
  /// six `idb ui swipe --delta 5` pulls of 50-300 pt moved it 40.0, 73.7,
  /// 99.3, 123.7, 146.7 and 168.3 pt; rms 1.4 pt). The constant usually
  /// quoted for UIKit, 0.55 with the whole viewport as reach, gives 139 pt
  /// at 300; Flutter's bouncing friction (0.52) gives 133.
  static const double rubberBandStiffness = 0.84;

  /// The rubber band's reach, the most the content can be pulled, as a
  /// fraction of the viewport's height (fitted with [rubberBandStiffness]:
  /// 491 pt in the 874-pt List).
  static const double rubberBandReach = 0.562;

  /// The room the indicator keeps while refreshing: the content is held
  /// this far down and the spinner centred in it. Measured from SwiftUI's
  /// `.refreshable` on iOS 26.4 (a plain List held 60.3 pt below its rest,
  /// spinner centred 30 pt below the list's top inset, two takes).
  static const double indicatorExtent = 60;

  /// The Material path's box around its ring. SwiftUI draws no disk
  /// behind the spinner (measured: the page around it stays pure white).
  static const double diskSize = 36;

  /// The spinner's diameter, spoke tip to spoke tip (measured: 30 pt,
  /// 186-216 across, centred 92 pt down on iPhone 17 Pro).
  static const double spinnerSize = 30;

  /// The Material ring's diameter.
  static const double ringSize = 20;

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
}

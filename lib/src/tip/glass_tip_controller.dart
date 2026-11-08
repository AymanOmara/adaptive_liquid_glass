import 'package:flutter/foundation.dart';

/// Why a tip went away, like TipKit's `Tip.InvalidationReason`.
enum GlassTipDismissReason {
  /// The close button, or a tap outside a popover tip.
  closed,

  /// The app dismissed it after the person did what the tip suggested.
  actionPerformed,
}

/// Whether a tip still shows, like a TipKit tip's status: the display rule
/// "show until dismissed" without hidden storage.
///
/// The package stores nothing. To show a tip once across launches, seed
/// [isDismissed] from your own storage and save it in [onDismissed]:
///
/// ```dart
/// final favoriteTip = GlassTipController(
///   dismissed: prefs.getBool('tip.favorite') ?? false,
///   onDismissed: (_) => prefs.setBool('tip.favorite', true),
/// );
/// ```
///
/// Share one controller between a [GlassTipView] and a `GlassPopoverTip`
/// of the same tip, and call [dismiss] with
/// [GlassTipDismissReason.actionPerformed] once the person has used the
/// feature the tip points to.
class GlassTipController extends ChangeNotifier {
  /// Creates a controller, already dismissed when [dismissed] is true.
  GlassTipController({bool dismissed = false, this.onDismissed})
    : _dismissed = dismissed;

  /// Called once each time the tip goes from shown to dismissed.
  final ValueChanged<GlassTipDismissReason>? onDismissed;

  bool _dismissed;

  /// Whether the tip no longer shows.
  bool get isDismissed => _dismissed;

  /// Hides the tip; does nothing when it is already dismissed.
  void dismiss([GlassTipDismissReason reason = GlassTipDismissReason.closed]) {
    if (_dismissed) return;
    _dismissed = true;
    notifyListeners();
    onDismissed?.call(reason);
  }

  /// Shows the tip again, like `Tips.resetDatastore()` for one tip.
  void reset() {
    if (!_dismissed) return;
    _dismissed = false;
    notifyListeners();
  }
}

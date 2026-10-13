import 'package:flutter/widgets.dart';

import 'tab_bar_metrics.dart';

/// Whether the tab bar is minimized, driven by the page's scrolling
/// (GlassScaffold) and by a tap on the minimized bar.
class TabBarMinimizeController extends ChangeNotifier {
  bool _minimized = false;
  double _down = 0;
  double? _last;

  /// Whether the bar is shrunk to its selected tab.
  bool get minimized => _minimized;

  /// Follows a vertical scroll position [pixels] from its top [min]: iOS
  /// 26.4 minimizes after ~75 pt scrolled down since the bar was last
  /// expanded and expands again within ~15 pt of the top.
  void scrolled(double pixels, double min) {
    final offset = pixels - min;
    final last = _last ?? offset;
    _last = offset;
    final delta = offset - last;
    if (offset <= TabBarMetrics.minimizeExpandOffset) {
      _down = 0;
      _set(false);
      return;
    }
    _down = (_down + delta).clamp(0.0, double.infinity);
    if (_down >= TabBarMetrics.minimizeDistance) _set(true);
  }

  /// Expands the bar (a tap on the minimized bar).
  void expand() {
    _down = 0;
    _set(false);
  }

  void _set(bool value) {
    if (value == _minimized) return;
    _minimized = value;
    notifyListeners();
  }
}

/// Hands a [TabBarMinimizeController] down to the tab bar.
class TabBarMinimizeScope extends InheritedNotifier<TabBarMinimizeController> {
  /// Provides [controller] to [child].
  const TabBarMinimizeScope({
    super.key,
    required TabBarMinimizeController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The nearest controller, or null.
  static TabBarMinimizeController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<TabBarMinimizeScope>()
      ?.notifier;
}

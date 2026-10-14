import 'package:flutter/widgets.dart';

import 'tab_bar_minimize_controller.dart';

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

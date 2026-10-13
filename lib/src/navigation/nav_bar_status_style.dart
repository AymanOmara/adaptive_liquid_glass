import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter/widgets.dart';

import '../core/glass_brightness.dart';

/// Gives the status bar the glyph colour of the page under a glass
/// navigation bar (dark glyphs on a light page, light on a dark one), as
/// iOS's navigation bar does. Without it, Android keeps whatever style the
/// previous route set, such as an `AppBar`'s light glyphs on a light page.
class NavBarStatusStyle extends StatelessWidget {
  /// Creates the status bar style scope.
  const NavBarStatusStyle({super.key, required this.child});

  /// The navigation bar.
  final Widget child;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: glassBrightnessOf(context) == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark,
    child: child,
  );
}

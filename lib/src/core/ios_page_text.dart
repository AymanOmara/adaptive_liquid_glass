import 'package:flutter/cupertino.dart';

import 'ios_text.dart';

/// [child] with iOS's body text (17 pt, the label colour) as its default
/// style. A glass route's page sits under the Navigator's overlay, which
/// has no text style of its own: without this its text falls back to
/// Flutter's debug style (yellow underlines).
///
/// The colour resolves inside a [Builder], below the themes a route
/// captures from the presenting context, so it follows the caller's
/// appearance, not the navigator's.
Widget iosPageText(Widget child) => Builder(
  builder: (context) => DefaultTextStyle(
    style: IOSText.style(
      17,
      color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
    ),
    child: child,
  ),
);

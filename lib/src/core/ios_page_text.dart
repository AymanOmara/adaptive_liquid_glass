import 'package:flutter/cupertino.dart';

import 'ios_text.dart';

/// [child] with iOS's body text (17 pt, the label colour) as its default
/// style. A glass route's page sits under the Navigator's overlay, which
/// has no text style of its own: without this its text falls back to
/// Flutter's debug style (yellow underlines).
Widget iosPageText(BuildContext context, Widget child) => DefaultTextStyle(
  style: IOSText.style(
    17,
    color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
  ),
  child: child,
);

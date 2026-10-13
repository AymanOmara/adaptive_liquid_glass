import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;

import 'glass_colors.dart';
import 'ios_text.dart';

/// [child] with iOS's body text (17 pt, the label colour) as its default
/// style. A glass route's page sits under the Navigator's overlay, which
/// has no text style of its own: without this its text falls back to
/// Flutter's debug style (yellow underlines).
///
/// A transparent [Material] goes with it, so Material widgets an app puts
/// on the glass (a `ListTile`, a `TextField`) find the ancestor they need;
/// it draws nothing.
///
/// The colour resolves inside a [Builder], below the themes a route
/// captures from the presenting context, so it follows the caller's
/// appearance, not the navigator's.
Widget iosPageText(Widget child) => Builder(
  builder: (context) {
    final style = IOSText.inFontOf(
      IOSText.style(
        17,
        color: CupertinoDynamicColor.resolve(GlassColors.label, context),
      ),
      DefaultTextStyle.of(context).style,
    );
    return Material(
      type: MaterialType.transparency,
      textStyle: style,
      child: DefaultTextStyle(style: style, child: child),
    );
  },
);

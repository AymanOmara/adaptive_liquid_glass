import 'package:flutter/cupertino.dart';

/// The appearance glass and its content draw with, or null without a theme
/// brightness or a `MediaQuery` in scope.
///
/// One rule for both, so they always agree: the brightness Cupertino
/// colours resolve against (`CupertinoDynamicColor.resolve` reads the same
/// value). That is `CupertinoThemeData.brightness` when set, inside a
/// `MaterialApp` the Material theme's brightness (its
/// `MaterialBasedCupertinoThemeData`), and otherwise the platform
/// brightness. An app whose theme disagrees with the system appearance gets
/// glass in its theme's appearance, as a native app with
/// `overrideUserInterfaceStyle` does, instead of dark glass under dark text.
Brightness? glassBrightnessOf(BuildContext context) =>
    CupertinoTheme.maybeBrightnessOf(context);

import 'package:flutter/cupertino.dart';

/// The Cupertino localizations at [context], or English defaults where an
/// app provides none (a bare `WidgetsApp`, a test host): glass components
/// must not require a `CupertinoApp` or `MaterialApp`.
CupertinoLocalizations cupertinoL10n(BuildContext context) =>
    Localizations.of<CupertinoLocalizations>(context, CupertinoLocalizations) ??
    const DefaultCupertinoLocalizations();

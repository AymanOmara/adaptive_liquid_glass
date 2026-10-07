import 'package:flutter/widgets.dart';

/// Gives text and icons on glass [color], like SwiftUI's vibrant labels.
///
/// ```dart
/// GlassLabelStyle(
///   color: GlassForeground.labelColorOf(context),
///   child: const Text('On glass'),
/// )
/// ```
///
/// Glass surfaces apply it to their content already (see
/// `GlassMember.adaptiveForeground`); use it directly for custom content
/// that should read like a label on the glass. Merges into the ambient
/// [DefaultTextStyle] and [IconTheme], so a colour the app sets on a
/// `Text` or `Icon` still wins.
class GlassLabelStyle extends StatelessWidget {
  /// Creates the style scope.
  const GlassLabelStyle({super.key, required this.color, required this.child});

  /// Colour for text and icons that do not set their own.
  final Color color;

  /// Content on the glass.
  final Widget child;

  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
    style: TextStyle(color: color),
    child: IconTheme.merge(
      data: IconThemeData(color: color),
      child: child,
    ),
  );
}

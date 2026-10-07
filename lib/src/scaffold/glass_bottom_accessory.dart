import 'package:flutter/widgets.dart';

import '../core/glass.dart';
import '../core/glass_colors.dart';
import '../core/glass_render_mode.dart';
import '../core/ios_text.dart';
import '../foreground/glass_foreground.dart';
import '../liquid_glass.dart';
import 'scaffold_metrics.dart';

/// iOS 26's tab bar bottom accessory (Music's mini-player): a full-width
/// glass capsule floating just above the tab bar.
///
/// Give it to [GlassScaffold.bottomAccessory]; the scaffold places it and
/// pads the body clear of it.
///
/// ```dart
/// GlassBottomAccessory(
///   onPressed: openPlayer,
///   child: const Text('Now Playing'),
/// )
/// ```
class GlassBottomAccessory extends StatelessWidget
    implements PreferredSizeWidget {
  /// Creates an accessory.
  const GlassBottomAccessory({
    super.key,
    required this.child,
    this.onPressed,
    this.glass,
    this.mode,
  });

  /// The content, laid out in a row-height box; usually a [Row].
  final Widget child;

  /// Makes the whole accessory a button.
  final VoidCallback? onPressed;

  /// The glass. Defaults to the theme's default glass.
  final Glass? glass;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  Size get preferredSize =>
      const Size.fromHeight(ScaffoldMetrics.accessoryHeight);

  @override
  Widget build(BuildContext context) => SizedBox(
    height: ScaffoldMetrics.accessoryHeight,
    width: double.infinity,
    child: LiquidGlass(
      glass: glass,
      mode: mode,
      onPressed: onPressed,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      // SwiftUI's accessory content is body text: 17 pt, in the primary
      // label colour (black on the light bar, not the 85 % of vibrant
      // labels on glass), dark or light by what is behind the glass.
      child: Builder(
        builder: (context) {
          final color =
              GlassForeground.backgroundBrightnessOf(context) ==
                  Brightness.light
              ? GlassColors.label.color
              : GlassColors.label.darkColor;
          return DefaultTextStyle.merge(
            style: IOSText.style(17).copyWith(color: color),
            child: IconTheme.merge(
              data: IconThemeData(size: 20, color: color),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: child,
              ),
            ),
          );
        },
      ),
    ),
  );
}

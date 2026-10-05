import 'package:flutter/widgets.dart';

import 'core/glass.dart';
import 'core/glass_render_mode.dart';
import 'core/glass_shape.dart';
import 'core/theme.dart';
import 'group/glass_group.dart';
import 'group/glass_member.dart';
import 'shader/glass_program.dart';

/// Liquid Glass behind [child], like SwiftUI's `.glassEffect(_:in:)`.
///
/// On iOS this is shader glass (or Apple's own on iOS 26+ when
/// `LiquidGlassThemeData.nativeEnabled`); on Android a Material 3 surface.
class LiquidGlass extends StatelessWidget {
  /// Creates Liquid Glass.
  const LiquidGlass({
    super.key,
    this.glass,
    this.shape = const GlassShape.capsule(),
    this.glassId,
    this.unionId,
    this.mode,
    this.padding,
    this.adaptiveForeground = true,
    this.onPressed,
    required this.child,
  });

  /// The glass material; defaults to the theme's `defaultGlass`.
  final Glass? glass;

  /// The shape; defaults to a capsule.
  final GlassShape shape;

  /// Morph identity inside a `GlassGroup` (`glassEffectID`).
  final Object? glassId;

  /// Members with the same id merge into one shape (`glassEffectUnion`).
  final Object? unionId;

  /// Rendering mode when not inside a `GlassGroup` (a group's mode wins).
  final GlassRenderMode? mode;

  /// Space between the glass edge and [child]; null means none.
  ///
  /// Prefer [EdgeInsetsDirectional] so the inset follows the reading
  /// direction.
  final EdgeInsetsGeometry? padding;

  /// Whether text and icons on the glass take a readable colour.
  ///
  /// Like SwiftUI's vibrant labels: the [DefaultTextStyle] and [IconTheme]
  /// colour follow `GlassForeground.labelColorOf` (dark on light content,
  /// white on dark), or the Material "on" colour of the surface on the
  /// Material path. Colours set on a `Text` or `Icon` still win.
  final bool adaptiveForeground;

  /// Called when the glass is tapped or activated from the keyboard.
  ///
  /// When set, the glass is a button: it gets button semantics, takes
  /// focus, and answers Enter and Space. Its glass also becomes
  /// interactive (the press stretch and glow, or the Material ripple)
  /// unless [glass] opts out with `interactive(false)`.
  final VoidCallback? onPressed;

  /// Content drawn on the glass.
  final Widget child;

  /// Loads the shader ahead of the first frame. Call from `main()` to avoid
  /// a frame without glass at startup.
  static Future<void> precache() => GlassProgram.instance.load();

  @override
  Widget build(BuildContext context) {
    final resolved = glass ?? LiquidGlassTheme.of(context).defaultGlass;
    final member = GlassMember(
      glass: onPressed == null ? resolved : pressableGlass(resolved),
      shape: shape,
      glassId: glassId,
      unionId: unionId,
      mode: mode,
      adaptiveForeground: adaptiveForeground,
      onPressed: onPressed,
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
    return GlassGroupScope.maybeOf(context) == null
        ? GlassGroup(mode: mode, child: member)
        : member;
  }
}

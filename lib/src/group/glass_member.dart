import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/glass.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_shape.dart';
import '../core/glass_variant.dart';
import '../degraded/degraded_glass.dart';
import '../degraded/glass_loading_surface.dart';
import '../foreground/glass_foreground.dart';
import '../foreground/glass_label_style.dart';
import '../interaction/glass_pressable.dart';
import '../interaction/press_controller.dart';
import '../material/material_glass.dart';
import '../shader/glass_program.dart';
import 'concentric_scope.dart';
import 'content_fade.dart';
import 'glass_entry.dart';
import 'glass_group.dart';
import 'glass_group_scope.dart';
import 'glass_member_box.dart';
import 'glass_member_rendering.dart';
import 'glass_press_geometry.dart';
import 'glass_registry.dart';
import 'scroll_chain.dart';

/// The glass shader program, or null until it has loaded.
///
/// Members on the shader path show a blur-only surface until then.
/// Replaceable in tests: the shader asset does not load under
/// `flutter test`.
@visibleForTesting
ValueListenable<Object?> glassShaderProgram = GlassProgram.instance.program;

/// A `LiquidGlass` inside a group. Internal.
class GlassMember extends StatefulWidget {
  /// Creates a member.
  const GlassMember({
    super.key,
    required this.glass,
    required this.shape,
    required this.glassId,
    required this.unionId,
    required this.mode,
    this.adaptiveForeground = true,
    this.onPressed,
    required this.child,
  });

  /// See `LiquidGlass.glass`.
  final Glass glass;

  /// See `LiquidGlass.shape`.
  final GlassShape shape;

  /// See `LiquidGlass.glassId`.
  final Object? glassId;

  /// See `LiquidGlass.unionId`.
  final Object? unionId;

  /// See `LiquidGlass.mode`.
  final GlassRenderMode? mode;

  /// See `LiquidGlass.adaptiveForeground`.
  final bool adaptiveForeground;

  /// See `LiquidGlass.onPressed`.
  final VoidCallback? onPressed;

  /// Content.
  final Widget child;

  @override
  State<GlassMember> createState() => GlassMemberState();
}

/// State of [GlassMember]. Library-public so the widget and its tests can
/// name the type; not exported by `adaptive_liquid_glass.dart`.
class GlassMemberState extends State<GlassMember>
    with SingleTickerProviderStateMixin {
  /// The registry record for this member.
  late final GlassEntry entry = GlassEntry(
    shape: widget.shape,
    glass: widget.glass,
    glassId: widget.glassId,
    unionId: widget.unionId,
  );

  /// The registry this member is registered with; null when it is not
  /// drawn by the group's backdrop or native layer, or when it overflowed.
  GlassRegistry? _registry;

  /// The scope's registry last seen, registered with or not.
  GlassRegistry? _scopeRegistry;

  /// Scroll positions between this member and its group's scrollable.
  final List<Listenable> _scrolls = [];

  GlassPressController? _press;

  GlassPressController _pressController(GlassGroupScope scope) => _press ??=
      GlassPressController(vsync: this, motion: scope.constants.motion)
        ..addListener(() {
          // A spring still settling after the glass stopped being
          // interactive must not deform it.
          if (!widget.glass.isInteractive) return;
          entry.press = _press!.geometry();
          _registry?.markNeedsPaint();
        });

  bool _overflow = false;
  bool _fadeIn = false;
  bool _first = true;
  bool _settled = false;

  /// Box, morph rect and press held while deactivated (restored on
  /// reparent).
  RenderBox? _heldBox;
  Rect? _heldMorph;
  GlassPressGeometry _heldPress = GlassPressGeometry.identity;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = GlassGroupScope.of(context);
    if (_first) {
      _fadeIn = scope.settled && widget.glassId != null;
      _first = false;
    }
    _settled = scope.settled;
    entry.container = ConcentricScope.maybeOf(context);
    final target = scope.rendering.drawnByGroup ? scope.registry : null;
    if (!identical(target, _scopeRegistry)) {
      _registry?.unregister(entry);
      _scopeRegistry = target;
      final registered = target != null && target.register(entry);
      _overflow = target != null && !registered;
      _registry = registered ? target : null;
    }
    _subscribeScrolls(scope.scrollable);
  }

  void _onScroll() => _registry?.markNeedsPaint();

  /// Scrolling inside the group moves this member without repainting the
  /// group: viewports are repaint boundaries. Listen to every scrollable
  /// between this member and the one the group already tracks.
  void _subscribeScrolls(ScrollableState? groupScrollable) {
    _unsubscribeScrolls();
    if (_registry == null) return;
    _scrolls.addAll(enclosingScrollPositions(context, stopAt: groupScrollable));
    for (final l in _scrolls) {
      l.addListener(_onScroll);
    }
  }

  void _unsubscribeScrolls() {
    for (final l in _scrolls) {
      l.removeListener(_onScroll);
    }
    _scrolls.clear();
  }

  @override
  void didUpdateWidget(GlassMember oldWidget) {
    super.didUpdateWidget(oldWidget);
    entry
      ..shape = widget.shape
      ..glass = widget.glass
      ..glassId = widget.glassId
      ..unionId = widget.unionId;
    _registry?.markNeedsPaint();
  }

  /// Removal detaches the box during build, but the member unregisters only
  /// when it is disposed, after paint. Keep drawing a morphing member at its
  /// last rect in between, so its ghost (see `GlassMorphController`)
  /// continues without a blank frame.
  @override
  void deactivate() {
    final last = entry.lastDrawnLocal;
    if (_registry != null &&
        _settled &&
        entry.glassId != null &&
        last != null &&
        entry.box != null) {
      _heldBox = entry.box;
      _heldMorph = entry.morphRect;
      _heldPress = entry.press;
      // `last` already includes the press; do not apply it twice.
      entry
        ..box = null
        ..morphRect = last
        ..press = GlassPressGeometry.identity;
      _registry!.markNeedsPaint();
    }
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    final held = _heldBox;
    if (held != null) {
      entry
        ..box = held
        ..morphRect = _heldMorph
        ..press = _heldPress;
      _heldBox = null;
      _heldMorph = null;
      _heldPress = GlassPressGeometry.identity;
      _registry?.markNeedsPaint();
    }
  }

  @override
  void dispose() {
    _heldBox = null;
    _unsubscribeScrolls();
    _press?.dispose();
    // Clear the box first so the morph controller recognises a ghost; a
    // ghost shrinks unpressed.
    entry
      ..box = null
      ..press = GlassPressGeometry.identity;
    _registry?.unregister(entry);
    entry.contentOpacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = GlassGroupScope.of(context);
    if (_overflow) {
      return GlassGroup(
        mode: scope.requestedMode,
        child: GlassMember(
          glass: widget.glass,
          shape: widget.shape,
          glassId: widget.glassId,
          unionId: widget.unionId,
          mode: widget.mode,
          adaptiveForeground: widget.adaptiveForeground,
          onPressed: widget.onPressed,
          child: widget.child,
        ),
      );
    }
    if (widget.glass.variant == GlassVariant.identity) {
      return _pressable(widget.child);
    }
    return switch (scope.rendering) {
      GlassMemberRendering.material => MaterialGlass(
        glass: widget.glass,
        shape: widget.shape,
        fadeIn: _fadeIn,
        adaptiveForeground: widget.adaptiveForeground,
        onPressed: widget.onPressed,
        pressable: true,
        child: widget.child,
      ),
      GlassMemberRendering.degraded => DegradedGlass(
        glass: widget.glass,
        shape: widget.shape,
        constants: scope.constants,
        opaqueColor: scope.opaqueColor,
        child: _labelled(context),
      ),
      GlassMemberRendering.backdrop ||
      GlassMemberRendering.native => ConcentricScope(
        entry: entry,
        child: GlassMemberBox(
          entry: entry,
          registry: _registry!,
          child: _untilShaderLoads(
            scope,
            buildContent(context, _labelled(context)),
          ),
        ),
      ),
    };
  }

  /// Blur-only glass on the shader path until the shader program loads,
  /// so the first frames are not bare content and `LiquidGlass.precache`
  /// stays optional. The tree is the same before and after (and with or
  /// without Reduce Transparency), so the switch keeps the content's state
  /// and layout; once off it adds no layer.
  ///
  /// It sits outside the content fade and the press transform on purpose:
  /// it is a transient stand-in for the backdrop's own drawing, which
  /// neither fades nor stretches with the content. Morphs start after the
  /// first frame, by which time the shader has usually loaded.
  Widget _untilShaderLoads(GlassGroupScope scope, Widget content) =>
      ValueListenableBuilder<Object?>(
        valueListenable: glassShaderProgram,
        builder: (context, program, content) => GlassLoadingSurface(
          glass: widget.glass,
          shape: widget.shape,
          constants: scope.constants,
          opaqueColor: scope.opaqueColor,
          enabled:
              program == null &&
              scope.rendering == GlassMemberRendering.backdrop,
          child: content!,
        ),
        child: content,
      );

  /// The child with vibrant label colours (when
  /// [GlassMember.adaptiveForeground]), as a button when pressable.
  Widget _labelled(BuildContext context) => _pressable(
    widget.adaptiveForeground
        ? GlassLabelStyle(
            color: GlassForeground.labelColorOf(context),
            child: widget.child,
          )
        : widget.child,
  );

  /// Always present, so toggling `onPressed` keeps the child mounted.
  Widget _pressable(Widget child) =>
      GlassPressable(onPressed: widget.onPressed, child: child);

  /// [content] as drawn on the glass: faded during `glassId` morphs and
  /// wrapped in the press transform (identity unless interactive).
  Widget buildContent(BuildContext context, Widget content) => ContentFade(
    opacity: entry.contentOpacity,
    child: _pressContent(context, content),
  );

  /// The listener and transform are built either way, at a fixed depth, so
  /// toggling interactivity keeps the content mounted; when not interactive
  /// they do nothing (an identity transform paints no layer).
  Widget _pressContent(BuildContext context, Widget content) {
    final scope = GlassGroupScope.of(context);
    final press = widget.glass.isInteractive
        ? (_pressController(scope)
            ..motion = scope.constants.motion
            ..reduceMotion = MediaQuery.disableAnimationsOf(context))
        : null;
    if (press == null) entry.press = GlassPressGeometry.identity;
    return Listener(
      behavior: press == null
          ? HitTestBehavior.deferToChild
          : HitTestBehavior.translucent,
      // The press maths measures the member box (GlassMemberBox), the
      // same box the renderer draws.
      onPointerDown: press == null
          ? null
          : (e) => press.down(e.localPosition, entry.box?.size ?? Size.zero),
      onPointerMove: press == null ? null : (e) => press.move(e.localPosition),
      onPointerUp: press == null ? null : (_) => press.up(),
      onPointerCancel: press == null ? null : (_) => press.up(),
      child: AnimatedBuilder(
        animation: press ?? _noPress,
        builder: (_, child) => Transform(
          transform: press?.contentTransform() ?? Matrix4.identity(),
          child: child,
        ),
        child: content,
      ),
    );
  }

  static const AlwaysStoppedAnimation<double> _noPress =
      AlwaysStoppedAnimation<double>(0);
}

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/glass.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_shape.dart';
import '../degraded/degraded_glass.dart';
import '../foreground/glass_foreground.dart';
import '../foreground/glass_label_style.dart';
import '../interaction/press_controller.dart';
import '../material/material_glass.dart';
import 'glass_entry.dart';
import 'glass_group.dart';
import 'glass_registry.dart';
import 'scroll_chain.dart';

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

  /// Content.
  final Widget child;

  @override
  State<GlassMember> createState() => GlassMemberState();
}

/// State of [GlassMember]. Public so later tasks can extend behaviour.
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
          child: widget.child,
        ),
      );
    }
    if (widget.glass.variant == GlassVariant.identity) return widget.child;
    return switch (scope.rendering) {
      GlassMemberRendering.material => MaterialGlass(
        glass: widget.glass,
        shape: widget.shape,
        fadeIn: _fadeIn,
        adaptiveForeground: widget.adaptiveForeground,
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
          child: buildContent(context, _labelled(context)),
        ),
      ),
    };
  }

  /// The child with vibrant label colours, when [GlassMember.adaptiveForeground].
  Widget _labelled(BuildContext context) => widget.adaptiveForeground
      ? GlassLabelStyle(
          color: GlassForeground.labelColorOf(context),
          child: widget.child,
        )
      : widget.child;

  /// [content] as drawn on the glass: faded during `glassId` morphs and,
  /// for interactive glass, wrapped in the press transform.
  Widget buildContent(BuildContext context, Widget content) => _ContentFade(
    opacity: entry.contentOpacity,
    child: _pressContent(context, content),
  );

  Widget _pressContent(BuildContext context, Widget content) {
    if (!widget.glass.isInteractive) {
      entry.press = GlassPressGeometry.identity;
      return content;
    }
    final scope = GlassGroupScope.of(context);
    final press = _pressController(scope)
      ..motion = scope.constants.motion
      ..reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Listener(
      behavior: HitTestBehavior.translucent,
      // The press maths measures the member box (GlassMemberBox), the
      // same box the renderer draws.
      onPointerDown: (e) =>
          press.down(e.localPosition, entry.box?.size ?? Size.zero),
      onPointerMove: (e) => press.move(e.localPosition),
      onPointerUp: (_) => press.up(),
      onPointerCancel: (_) => press.up(),
      child: AnimatedBuilder(
        animation: press,
        builder: (_, child) =>
            Transform(transform: press.contentTransform(), child: child),
        child: content,
      ),
    );
  }
}

/// Provides the enclosing glass entry to concentric descendants.
class ConcentricScope extends InheritedWidget {
  /// Creates the scope.
  const ConcentricScope({super.key, required this.entry, required super.child});

  /// The enclosing glass.
  final GlassEntry entry;

  /// Nearest enclosing entry.
  static GlassEntry? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ConcentricScope>()?.entry;

  @override
  bool updateShouldNotify(ConcentricScope old) => old.entry != entry;
}

/// Hands its render box to the entry and reports geometry changes.
class GlassMemberBox extends SingleChildRenderObjectWidget {
  /// Creates the box.
  const GlassMemberBox({
    super.key,
    required this.entry,
    required this.registry,
    super.child,
  });

  /// The member's entry.
  final GlassEntry entry;

  /// The member's registry.
  final GlassRegistry registry;

  @override
  RenderGlassMember createRenderObject(BuildContext context) {
    final r = RenderGlassMember(entry, registry);
    entry.box = r;
    return r;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassMember renderObject,
  ) {
    renderObject
      ..entry = entry
      ..registry = registry;
    entry.box = renderObject;
  }
}

/// See [GlassMemberBox].
class RenderGlassMember extends RenderProxyBox {
  /// Creates the render object.
  RenderGlassMember(this.entry, this.registry);

  /// The member's entry.
  GlassEntry entry;

  /// The member's registry.
  GlassRegistry registry;

  Matrix4? _lastTransform;

  @override
  void performLayout() {
    final old = hasSize ? size : null;
    super.performLayout();
    if (old != size) registry.markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    // This member repainted at a new global transform. The group may not
    // have repainted this frame (a repaint boundary sits between us), so
    // refresh it one frame late; the post-frame markNeedsPaint schedules
    // that frame. A boundary that only moves its layer does not re-run this
    // paint at all: scrolling is covered by the scroll listeners in
    // GlassGroup and GlassMemberState, and route motion by GlassGroup.
    final t = getTransformTo(null);
    if (_lastTransform != null && _lastTransform != t) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (attached) registry.markNeedsPaint();
      });
    }
    _lastTransform = t;
  }
}

/// Fades member content during morphs. Fixed tree depth (no remount when a
/// fade ends), no rebuild per tick, and no layer outside a fade.
class _ContentFade extends SingleChildRenderObjectWidget {
  const _ContentFade({required this.opacity, super.child});

  final ValueListenable<double> opacity;

  @override
  _RenderContentFade createRenderObject(BuildContext context) =>
      _RenderContentFade(opacity);

  @override
  void updateRenderObject(BuildContext context, _RenderContentFade r) =>
      r.opacity = opacity;
}

class _RenderContentFade extends RenderProxyBox {
  _RenderContentFade(this._opacity) : _alpha = _alphaOf(_opacity.value);

  static int _alphaOf(double v) => (v.clamp(0.0, 1.0) * 255).round();

  ValueListenable<double> _opacity;
  set opacity(ValueListenable<double> value) {
    if (identical(value, _opacity)) return;
    if (attached) _opacity.removeListener(_update);
    _opacity = value;
    if (attached) _opacity.addListener(_update);
    _update();
  }

  int _alpha;

  bool get _composites => child != null && _alpha > 0 && _alpha < 255;

  void _update() {
    final a = _alphaOf(_opacity.value);
    if (a == _alpha) return;
    final was = _composites;
    final wasVisible = _alpha > 0;
    _alpha = a;
    if (was != _composites) markNeedsCompositingBitsUpdate();
    if (wasVisible != (_alpha > 0)) markNeedsSemanticsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _composites;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _opacity.addListener(_update);
    _update();
  }

  @override
  void detach() {
    _opacity.removeListener(_update);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || _alpha == 0) {
      layer = null;
      return;
    }
    if (_alpha == 255) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    layer = context.pushOpacity(
      offset,
      _alpha,
      super.paint,
      oldLayer: layer as OpacityLayer?,
    );
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_alpha > 0) super.visitChildrenForSemantics(visitor);
  }
}

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'core/glass.dart';
import 'core/glass_render_mode.dart';
import 'core/glass_shape.dart';
import 'core/theme.dart';
import 'degraded/degraded_glass.dart';
import 'group/glass_entry.dart';
import 'group/glass_group.dart';
import 'group/glass_registry.dart';
import 'material/material_glass.dart';
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

  /// Content drawn on the glass.
  final Widget child;

  /// Loads the shader ahead of the first frame. Call from `main()` to avoid
  /// a frame without glass at startup.
  static Future<void> precache() => GlassProgram.instance.load();

  @override
  Widget build(BuildContext context) {
    final member = GlassMember(
      glass: glass ?? LiquidGlassTheme.of(context).defaultGlass,
      shape: shape,
      glassId: glassId,
      unionId: unionId,
      mode: mode,
      child: child,
    );
    return GlassGroupScope.maybeOf(context) == null
        ? GlassGroup(mode: mode, child: member)
        : member;
  }
}

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
    required this.child,
  });

  /// See [LiquidGlass.glass].
  final Glass glass;

  /// See [LiquidGlass.shape].
  final GlassShape shape;

  /// See [LiquidGlass.glassId].
  final Object? glassId;

  /// See [LiquidGlass.unionId].
  final Object? unionId;

  /// See [LiquidGlass.mode].
  final GlassRenderMode? mode;

  /// Content.
  final Widget child;

  @override
  State<GlassMember> createState() => GlassMemberState();
}

/// State of [GlassMember]. Public so later tasks can extend behaviour.
class GlassMemberState extends State<GlassMember> {
  /// The registry record for this member.
  late final GlassEntry entry = GlassEntry(
    shape: widget.shape,
    glass: widget.glass,
    glassId: widget.glassId,
    unionId: widget.unionId,
  );

  /// The registry this member is registered with; null when it is not
  /// drawn by the group's backdrop or when it overflowed.
  GlassRegistry? _registry;

  /// The scope's registry last seen, registered with or not.
  GlassRegistry? _scopeRegistry;

  /// Scroll positions between this member and its group's scrollable.
  final List<Listenable> _scrolls = [];

  bool _overflow = false;
  bool _fadeIn = false;
  bool _first = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = GlassGroupScope.of(context);
    if (_first) {
      _fadeIn = scope.settled && widget.glassId != null;
      _first = false;
    }
    entry.container = ConcentricScope.maybeOf(context);
    final target = scope.rendering == GlassMemberRendering.backdrop
        ? scope.registry
        : null;
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
    var scrollable = Scrollable.maybeOf(context);
    while (scrollable != null && !identical(scrollable, groupScrollable)) {
      _scrolls.add(scrollable.position);
      scrollable = Scrollable.maybeOf(scrollable.context);
    }
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

  @override
  void dispose() {
    _unsubscribeScrolls();
    _registry?.unregister(entry);
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
        child: widget.child,
      ),
      GlassMemberRendering.degraded => DegradedGlass(
        glass: widget.glass,
        shape: widget.shape,
        constants: scope.constants,
        opaqueColor: scope.opaqueColor,
        child: widget.child,
      ),
      GlassMemberRendering.backdrop => ConcentricScope(
        entry: entry,
        child: GlassMemberBox(
          entry: entry,
          registry: _registry!,
          child: buildContent(context),
        ),
      ),
    };
  }

  /// The child as drawn on the glass. Task 11 wraps it in the press
  /// transform; Task 12 adds the morph fade.
  Widget buildContent(BuildContext context) => widget.child;
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

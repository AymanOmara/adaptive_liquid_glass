import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/glass_constants.dart';
import '../core/glass_render_mode.dart';
import '../core/render_mode_resolver.dart';
import '../core/shape_border.dart';
import '../core/theme.dart';
import '../platform/glass_platform.dart';
import '../shader/glass_program.dart';
import '../shader/render_glass_backdrop.dart';
import 'glass_registry.dart';
import 'morph_controller.dart';

/// How members of a group render themselves.
enum GlassMemberRendering {
  /// Registered with the group's shader backdrop.
  backdrop,

  /// Each member is a Material surface.
  material,

  /// Each member is a blur-only surface.
  degraded,
}

/// Shares a group's registry and resolved mode with its members.
class GlassGroupScope extends InheritedWidget {
  /// Creates the scope.
  const GlassGroupScope({
    super.key,
    required this.registry,
    required this.rendering,
    required this.constants,
    required this.opaqueColor,
    required this.settled,
    required this.requestedMode,
    this.scrollable,
    required super.child,
  });

  /// The group's registry.
  final GlassRegistry registry;

  /// How members render.
  final GlassMemberRendering rendering;

  /// Constants.
  final GlassConstants constants;

  /// Reduce Transparency fill.
  final Color? opaqueColor;

  /// True after the group's first frame (members added later may animate in).
  final bool settled;

  /// The group's requested mode, reused for overflow groups.
  final GlassRenderMode? requestedMode;

  /// The nearest `Scrollable` enclosing the group, or null.
  ///
  /// The group repaints when it or any outer scrollable moves. Members
  /// listen to the scrollables between themselves and this one.
  final ScrollableState? scrollable;

  /// Nearest scope or null.
  static GlassGroupScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassGroupScope>();

  /// Nearest scope; asserts one exists.
  static GlassGroupScope of(BuildContext context) => maybeOf(context)!;

  @override
  bool updateShouldNotify(GlassGroupScope old) =>
      old.registry != registry ||
      old.rendering != rendering ||
      old.constants != constants ||
      old.opaqueColor != opaqueColor ||
      old.settled != settled ||
      old.requestedMode != requestedMode ||
      old.scrollable != scrollable;
}

/// Merges nearby `LiquidGlass` descendants into one shape, like SwiftUI's
/// `GlassEffectContainer(spacing:)`.
///
/// Inside a group, the group's [mode] wins over members' modes.
class GlassGroup extends StatefulWidget {
  /// Creates a group.
  const GlassGroup({
    super.key,
    this.spacing = 0,
    this.mode,
    required this.child,
  });

  /// Shapes closer than this (logical px) blend together.
  final double spacing;

  /// Rendering mode; defaults to the theme's.
  final GlassRenderMode? mode;

  /// Content containing `LiquidGlass` widgets.
  final Widget child;

  @override
  State<GlassGroup> createState() => _GlassGroupState();
}

class _GlassGroupState extends State<GlassGroup> with TickerProviderStateMixin {
  final GlassRegistry _registry = GlassRegistry();
  final List<Listenable> _motion = [];
  bool _settled = false;

  /// False between deactivate and activate/dispose: ancestor and render
  /// object lookups are not allowed then, and no ghost should start.
  bool _active = true;

  late final GlassMorphController _morph = GlassMorphController(
    vsync: this,
    registry: _registry,
    // The group's first render object: the backdrop when members register
    // with it, so morph rects share the renderer's local space.
    groupBox: () => _active ? context.findRenderObject() as RenderBox? : null,
    motion: () => _active
        ? context
                  .findAncestorWidgetOfExactType<LiquidGlassTheme>()
                  ?.data
                  .constants
                  .motion ??
              GlassConstants.standard.motion
        : GlassConstants.standard.motion,
  );

  @override
  void initState() {
    super.initState();
    _morph; // install the registry hooks before members register
    GlassPlatform.instance.ensureStarted();
    GlassPlatform.instance.environment.addListener(_onEnvironment);
    GlassProgram.instance.load();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _morph.markSettled();
      setState(() => _settled = true);
    });
  }

  @override
  void activate() {
    super.activate();
    _active = true;
  }

  @override
  void deactivate() {
    _active = false;
    super.deactivate();
  }

  void _onEnvironment() => setState(() {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribeMotion();
  }

  /// Repaint when an ancestor scrolls or the route animates: the shader
  /// samples screen-space pixels, and those ancestors move us without
  /// repainting us.
  void _subscribeMotion() {
    for (final l in _motion) {
      l.removeListener(_registry.markNeedsPaint);
    }
    _motion.clear();
    var scrollable = Scrollable.maybeOf(context);
    while (scrollable != null) {
      _motion.add(scrollable.position);
      scrollable = Scrollable.maybeOf(scrollable.context);
    }
    final route = ModalRoute.of(context);
    if (route != null) {
      final a = route.animation;
      final s = route.secondaryAnimation;
      if (a != null) _motion.add(a);
      if (s != null) _motion.add(s);
    }
    for (final l in _motion) {
      l.addListener(_registry.markNeedsPaint);
    }
  }

  @override
  void dispose() {
    for (final l in _motion) {
      l.removeListener(_registry.markNeedsPaint);
    }
    GlassPlatform.instance.environment.removeListener(_onEnvironment);
    _morph.dispose();
    _registry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = LiquidGlassTheme.of(context);
    final environment = GlassPlatform.instance.environment.value;
    final mode = resolveGlassMode(
      requested: widget.mode ?? theme.defaultMode,
      nativeEnabled: theme.nativeEnabled,
      environment: environment,
    );
    final opaque = mode == EffectiveGlassMode.opaque
        ? opaqueGlassColor(MediaQuery.platformBrightnessOf(context))
        : null;
    final rendering = switch (mode) {
      EffectiveGlassMode.material => GlassMemberRendering.material,
      EffectiveGlassMode.degraded => GlassMemberRendering.degraded,
      EffectiveGlassMode.opaque =>
        environment.shaderSupported
            ? GlassMemberRendering.backdrop
            : GlassMemberRendering.degraded,
      // Task 13 gives native its own path.
      EffectiveGlassMode.shader ||
      EffectiveGlassMode.native => GlassMemberRendering.backdrop,
    };

    final Widget scoped = GlassGroupScope(
      registry: _registry,
      rendering: rendering,
      constants: theme.constants,
      opaqueColor: opaque,
      settled: _settled,
      requestedMode: widget.mode,
      scrollable: Scrollable.maybeOf(context),
      child: widget.child,
    );
    if (rendering != GlassMemberRendering.backdrop) return scoped;

    return GlassBackdrop(
      registry: _registry,
      backdropKey: BackdropGroup.of(context)?.backdropKey,
      config: GlassBackdropConfig(
        spacing: widget.spacing,
        lightAngle: theme.lightAngle,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        constants: theme.constants,
        brightness: MediaQuery.platformBrightnessOf(context),
        highContrast: MediaQuery.highContrastOf(context),
        opaqueColor: opaque,
      ),
      child: scoped,
    );
  }
}

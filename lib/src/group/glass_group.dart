import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/glass_constants.dart';
import '../core/glass_render_mode.dart';
import '../core/render_mode_resolver.dart';
import '../core/shape_border.dart';
import '../core/theme.dart';
import '../foreground/glass_backdrop_source.dart';
import '../foreground/glass_foreground.dart';
import '../native/native_glass_layer.dart';
import '../platform/glass_platform.dart';
import '../shader/glass_program.dart';
import '../shader/render_glass_backdrop.dart';
import 'glass_registry.dart';
import 'morph_controller.dart';
import 'scroll_chain.dart';

/// How members of a group render themselves.
enum GlassMemberRendering {
  /// Registered with the group's shader backdrop.
  backdrop,

  /// Each member is a Material surface.
  material,

  /// Each member is a blur-only surface.
  degraded,

  /// Registered with the group's native (UIKit) glass layer, iOS 26+.
  native;

  /// Whether the group draws its members' glass (shader backdrop or native
  /// layer) rather than each member drawing its own surface.
  bool get drawnByGroup =>
      this == GlassMemberRendering.backdrop ||
      this == GlassMemberRendering.native;
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
/// Members are drawn in one pass, sample the same backdrop, and can morph
/// into each other by `glassId`. Shapes closer than [spacing] blend; with
/// the default of 0 only touching shapes do, so a row of separate buttons
/// stays separate. Set [spacing] to at least the gap between members to
/// make them flow together as they near.
///
/// ```dart
/// GlassGroup(
///   spacing: 16, // >= the 12 px gap: the buttons blend
///   child: Row(
///     mainAxisSize: MainAxisSize.min,
///     spacing: 12,
///     children: [
///       const Icon(Icons.edit).glassEffect(padding: const EdgeInsets.all(14)),
///       const Icon(Icons.share).glassEffect(padding: const EdgeInsets.all(14)),
///     ],
///   ),
/// )
/// ```
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

  /// Shapes closer than this (logical px) blend together; 0 (the default)
  /// blends only shapes that touch.
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

  Timer? _sampler;
  Brightness? _sampled;
  bool _sampling = false;

  late final GlassMorphController _morph = GlassMorphController(
    vsync: this,
    registry: _registry,
    // The group's first render object: the backdrop (or the native layer's
    // stack) when members register with it, so morph rects share the
    // renderer's local space.
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
    GlassBackdropSources.instance.revision.addListener(_onSources);
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

  void _onSources() {
    void rebuild() {
      if (mounted && _active) setState(() {});
    }

    // Sources register from initState, i.e. during build: defer then.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => rebuild());
    } else {
      rebuild();
    }
  }

  void _updateSampler(GlassMemberRendering rendering) {
    final want =
        rendering.drawnByGroup &&
        GlassBackdropSources.instance.boundaries.isNotEmpty;
    if (want && _sampler == null) {
      _sampler = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => _sample(),
      );
    } else if (!want) {
      _sampler?.cancel();
      _sampler = null;
      _sampled = null;
    }
  }

  Future<void> _sample() async {
    if (_sampling || !mounted || !_active) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    _sampling = true;
    try {
      final region = MatrixUtils.transformRect(
        box.getTransformTo(null),
        Offset.zero & box.size,
      );
      for (final b in GlassBackdropSources.instance.boundaries) {
        final l = await sampleLuminance(b, region);
        if (l == null) continue;
        final next = l >= 0.5 ? Brightness.light : Brightness.dark;
        if (mounted && next != _sampled) setState(() => _sampled = next);
        break;
      }
    } finally {
      _sampling = false;
    }
  }

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
    _motion
      ..clear()
      ..addAll(enclosingScrollPositions(context));
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
    GlassBackdropSources.instance.revision.removeListener(_onSources);
    _sampler?.cancel();
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
      EffectiveGlassMode.shader => GlassMemberRendering.backdrop,
      EffectiveGlassMode.native => GlassMemberRendering.native,
    };

    _updateSampler(rendering);
    // Only the shader path needs the program (idempotent); the Material,
    // degraded and native paths never load it.
    if (rendering == GlassMemberRendering.backdrop) {
      GlassProgram.instance.load();
    }

    Widget scoped = GlassGroupScope(
      registry: _registry,
      rendering: rendering,
      constants: theme.constants,
      opaqueColor: opaque,
      settled: _settled,
      requestedMode: widget.mode,
      scrollable: Scrollable.maybeOf(context),
      child: widget.child,
    );
    final sampled = _sampled;
    if (sampled != null) {
      scoped = GlassForeground(backgroundBrightness: sampled, child: scoped);
    }
    if (rendering == GlassMemberRendering.native) {
      return NativeGlassLayer(
        registry: _registry,
        spacing: widget.spacing,
        child: scoped,
      );
    }
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

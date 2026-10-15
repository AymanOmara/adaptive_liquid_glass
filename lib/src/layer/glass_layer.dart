import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../shader/render_glass_backdrop.dart';
import 'glass_layer_plan.dart';

const String _define = String.fromEnvironment(
  'ADAPTIVE_LIQUID_GLASS_SHARED_LAYER',
);

/// Internal switch for the shared glass layer
/// (docs/superpowers/plans/2026-10-15-shared-glass-layer.md).
///
/// On by default on Android, where every shader backdrop costs a
/// full-screen offscreen target under Impeller; off elsewhere.
/// `--dart-define=ADAPTIVE_LIQUID_GLASS_SHARED_LAYER=on|off` forces it.
abstract final class GlassSharedLayer {
  /// Forces the switch in tests; null follows the platform default.
  @visibleForTesting
  static bool? debugEnabled;

  /// Whether shader glass on [platform] draws through the shared layer.
  static bool enabledFor(TargetPlatform platform) =>
      debugEnabled ??
      switch (_define) {
        'on' => true,
        'off' => false,
        _ => platform == TargetPlatform.android,
      };
}

/// Turns the shared glass layer off for the glass below (it then draws
/// group by group, as without the layer).
///
/// For glass outside the normal paint order of its route: an
/// `OverlayPortal` child (menus) or a `CompositedTransformFollower`.
class GlassLayerOptOut extends InheritedWidget {
  /// Opts [child]'s glass out of the shared layer.
  const GlassLayerOptOut({super.key, required super.child});

  /// Whether [context] is opted out.
  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<GlassLayerOptOut>() != null;

  @override
  bool updateShouldNotify(GlassLayerOptOut oldWidget) => false;
}

/// Marks content composited by the shared layer's slot (a group's content,
/// or [GlassLayerContent]'s child) rather than in place.
///
/// Backdrop effects within it (the tab bar's vibrancy) paint plain there:
/// a backdrop filter in deferred content draws nothing on Impeller.
class GlassLayerDeferred extends InheritedWidget {
  /// Marks [child] as deferred when [deferred].
  const GlassLayerDeferred({
    super.key,
    required this.deferred,
    required super.child,
  });

  /// Whether the content is composited by the shared layer.
  final bool deferred;

  /// Whether [context] is in deferred content.
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<GlassLayerDeferred>()
          ?.deferred ??
      false;

  @override
  bool updateShouldNotify(GlassLayerDeferred oldWidget) =>
      deferred != oldWidget.deferred;
}

/// The shared glass of one route: the groups that draw through it and the
/// slots (one per group's `OverlayPortal`) of which the first paints it.
class GlassLayer {
  GlassLayer._();

  static final Expando<GlassLayer> _byKey = Expando<GlassLayer>();

  /// The layer for [key] (a route).
  static GlassLayer of(Object key) => _byKey[key] ??= GlassLayer._();

  final List<RenderGlassBackdrop> _clients = [];
  final List<RenderBox> _slots = [];
  bool _postFrameScheduled = false;

  /// The groups, in registration order.
  List<RenderGlassBackdrop> get clients => List.unmodifiable(_clients);

  /// The slot that paints the layer: the first attached one.
  RenderBox? get painter {
    for (final s in _slots) {
      if (s.attached) return s;
    }
    return null;
  }

  /// The last plan the painter drew; for tests.
  List<LayerStratum>? debugLastPlan;

  /// Adds a group.
  void addClient(RenderGlassBackdrop c) {
    if (!_clients.contains(c)) _clients.add(c);
    markNeedsPaint();
  }

  /// Removes a group.
  void removeClient(RenderGlassBackdrop c) {
    if (_clients.remove(c)) markNeedsPaint();
  }

  /// Adds a slot.
  void addSlot(RenderBox s) {
    if (!_slots.contains(s)) _slots.add(s);
    markNeedsPaint();
  }

  /// Removes a slot; the next one takes over painting.
  void removeSlot(RenderBox s) {
    if (_slots.remove(s)) markNeedsPaint();
  }

  /// Repaints the layer now (outside the paint phase).
  void markNeedsPaint() {
    final p = painter;
    if (p == null) return;
    final owner = p.owner;
    if (owner != null && owner.debugDoingPaint) {
      markNeedsPaintAfterFrame();
    } else {
      p.markNeedsPaint();
    }
  }

  /// Repaints the layer after this frame (from the paint phase, where
  /// marking another render object is not allowed).
  void markNeedsPaintAfterFrame() {
    if (_postFrameScheduled) return;
    _postFrameScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _postFrameScheduled = false;
        painter?.markNeedsPaint();
      })
      ..ensureVisualUpdate();
  }
}

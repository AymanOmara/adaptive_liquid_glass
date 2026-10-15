import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../group/glass_group_scope.dart';
import '../group/glass_registry.dart';
import '../layer/glass_layer.dart';
import 'native_glass_layer.dart';

/// Draws the native glass of the ungrouped `LiquidGlass` widgets below it
/// in one platform view, on iOS 26+.
///
/// A `LiquidGlass` outside any `GlassGroup` gets a group of its own, and on
/// iOS 26 every group hosts a native (SwiftUI) platform view, which is slow
/// to create: a sheet of 29 chips made 29 views and stalled for about a
/// second. Put a batch around such content and those groups draw through
/// the batch's single view instead. Unlike a `GlassGroup`, a batch never
/// merges anything: each glass keeps its own group (morphs, unions,
/// brightness), the shapes only share a view, with spacing 0.
///
/// ```dart
/// SingleChildScrollView(
///   child: GlassBatch(
///     child: Wrap(
///       spacing: 8,
///       runSpacing: 8,
///       children: [for (final tag in tags) GlassChip(label: tag)],
///     ),
///   ),
/// )
/// ```
///
/// The batch's view sits behind the batch's whole child, so batched glass
/// is drawn beneath everything in it. Glass therefore joins only where that
/// looks the same as its own view would, and otherwise keeps a view of its
/// own (correct, just not batched):
///
/// * **Scrolling**: glass inside a scroll view joins only a batch inside
///   that same scroll view (around the scrolled content, as above), so the
///   view scrolls with it and the viewport clips it.
/// * **Content beneath**: glass over something else in the batch (a
///   coloured, decorated or custom-painted ancestor, a card or `Material`,
///   a backdrop filter, or an earlier sibling it overlaps, glass included)
///   keeps its own view, since the batch's view would draw under that.
/// * **Clips and transforms**: glass partly cut by a clip between it and
///   the batch, or rotated or skewed relative to it, keeps its own view.
///   Glass clipped away entirely, or not painted (`Offstage`, zero
///   opacity), is left out; other opacity between it and the batch is
///   applied to its glass.
/// * **Overlays and other paths**: glass shown through an `OverlayPortal`
///   (menus, popovers) or a `CompositedTransformFollower`, in a different
///   brightness, or drawn by the shader or Material paths, is unaffected.
///
/// Glass that leaves a batch for these reasons keeps its own view from
/// then on. Glass inside an explicit `GlassGroup` is that group's, never a
/// batch's. With `LiquidGlassThemeData.batchImplicitGroups`, sheets and
/// `GlassScaffold` bodies place a batch themselves. Without native glass
/// (Android, older iOS, shader mode) a batch only lays out its child.
class GlassBatch extends StatefulWidget {
  /// Batches the native glass of [child].
  const GlassBatch({super.key, required this.child});

  /// Content containing ungrouped `LiquidGlass` widgets.
  final Widget child;

  @override
  State<GlassBatch> createState() => _GlassBatchState();
}

class _GlassBatchState extends State<GlassBatch> {
  late final NativeGlassBatch _batch = NativeGlassBatch(
    hostBox: () => mounted ? context.findRenderObject() as RenderBox? : null,
    onClientsChanged: _onClients,
  );

  /// Whether the view exists: only while some group draws through it.
  bool _hasClients = false;

  void _onClients() {
    void update() {
      if (!mounted || _hasClients == _batch.hasClients) return;
      setState(() => _hasClients = _batch.hasClients);
    }

    // Groups join while building and leave while unmounting.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance
        ..addPostFrameCallback((_) => update())
        ..ensureVisualUpdate();
    } else {
      update();
    }
  }

  @override
  void dispose() {
    _batch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GlassBatchScope(
    batch: _batch,
    scrollable: Scrollable.maybeOf(context),
    brightness: GlassGroupScope.maybeBrightnessOf(context),
    // Passthrough and a fixed slot, as NativeGlassLayer: the child keeps
    // its constraints and is never remounted when the view comes or goes.
    child: Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -kNativeOverhang,
          top: -kNativeOverhang,
          right: -kNativeOverhang,
          bottom: -kNativeOverhang,
          child: _hasClients
              ? NativeGlassView(
                  spacing: 0,
                  repaint: _batch,
                  shapes: _batch.shapes,
                )
              : const SizedBox.shrink(),
        ),
        widget.child,
      ],
    ),
  );
}

/// A group's native layer as a batch sees it.
abstract interface class NativeGlassBatchClient {
  /// The group's members.
  GlassRegistry get registry;

  /// The group's render box (morph rects are local to it).
  RenderBox? get groupBox;

  /// Called when the batch gives the group back: it must draw its own view.
  void eject();
}

/// Shares a [GlassBatch] with the implicit groups below it.
class GlassBatchScope extends InheritedWidget {
  /// Creates the scope.
  const GlassBatchScope({
    super.key,
    required this.batch,
    required this.scrollable,
    required this.brightness,
    required super.child,
  });

  /// The batch.
  final NativeGlassBatch batch;

  /// The scroll view the batch is in; only glass in the same one joins.
  final ScrollableState? scrollable;

  /// The brightness the batch's view draws with.
  final Brightness? brightness;

  /// The batch an implicit group's native layer at [context] may draw
  /// through, or null: none above, or one the build-time rules rule out
  /// (see [GlassBatch]). Render-tree rules are checked by the batch when
  /// it draws.
  static NativeGlassBatch? joinable(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GlassBatchScope>();
    if (scope == null) return null;
    if (!identical(Scrollable.maybeOf(context), scope.scrollable)) return null;
    if (GlassLayerOptOut.of(context)) return null;
    if (GlassGroupScope.maybeBrightnessOf(context) != scope.brightness) {
      return null;
    }
    var paints = false;
    context.visitAncestorElements((e) {
      final w = e.widget;
      if (identical(w, scope)) return false;
      paints = _widgetPaintsBeneath(w);
      return !paints;
    });
    return paints ? null : scope.batch;
  }

  /// Whether [w] paints something beneath its child (the batch's view
  /// would be drawn under it).
  static bool _widgetPaintsBeneath(Widget w) => switch (w) {
    ColoredBox(:final color) => color.a > 0,
    DecoratedBox(:final decoration, :final position) =>
      position == DecorationPosition.background && !_isBlank(decoration),
    PhysicalModel(:final color) => color.a > 0,
    PhysicalShape(:final color) => color.a > 0,
    CustomPaint(:final painter) => painter != null,
    BackdropFilter() => true,
    _ => false,
  };

  @override
  bool updateShouldNotify(GlassBatchScope old) =>
      old.batch != batch ||
      old.scrollable != scrollable ||
      old.brightness != brightness;
}

/// Whether [d] paints nothing.
bool _isBlank(Decoration d) =>
    d is BoxDecoration &&
    (d.color == null || d.color!.a == 0) &&
    d.gradient == null &&
    d.image == null &&
    d.border == null &&
    (d.boxShadow == null || d.boxShadow!.isEmpty);

/// What lies between a batched group and the batch.
typedef _Path = ({bool hidden, double opacity, Rect? clip});

/// The groups drawing through one [GlassBatch] view; notifies when any of
/// them changes.
class NativeGlassBatch extends ChangeNotifier {
  /// Creates a batch.
  NativeGlassBatch({required this.hostBox, required this.onClientsChanged});

  /// The batch's render box (its view is its first child).
  final RenderBox? Function() hostBox;

  /// Called when the batch gains its first group or loses its last.
  final VoidCallback onClientsChanged;

  final List<NativeGlassBatchClient> _clients = [];
  final Map<NativeGlassBatchClient, GlassRegistry> _registries = {};

  /// Opacity animations between groups and the batch, listened to.
  Set<Listenable> _animations = {};
  bool _disposed = false;

  /// Whether any group draws through the batch.
  bool get hasClients => _clients.isNotEmpty;

  /// The groups drawing through the batch.
  @visibleForTesting
  List<NativeGlassBatchClient> get clients => List.unmodifiable(_clients);

  /// Adds [c].
  void add(NativeGlassBatchClient c) {
    if (_disposed || _clients.contains(c)) return;
    _clients.add(c);
    final r = c.registry;
    _registries[c] = r;
    r.addListener(_changed);
    if (_clients.length == 1) onClientsChanged();
    notifyListeners();
  }

  /// Removes [c].
  void remove(NativeGlassBatchClient c) {
    if (_disposed || !_detach(c)) return;
    if (_clients.isEmpty) onClientsChanged();
    notifyListeners();
  }

  bool _detach(NativeGlassBatchClient c) {
    if (!_clients.remove(c)) return false;
    _registries.remove(c)?.removeListener(_changed);
    return true;
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// The batched shapes, in global coordinates. Groups the batch cannot
  /// draw faithfully are given back (see [GlassBatch]).
  List<NativeGlassShape>? shapes() {
    final host = hostBox();
    if (host == null || !host.attached || !host.hasSize) return null;
    final out = <NativeGlassShape>[];
    final animations = <Listenable>{};
    final ejected = <NativeGlassBatchClient>[];
    for (final c in _clients) {
      final box = c.groupBox;
      final geometry = nativeGroupGeometry(box, c.registry);
      if (box == null || geometry == null) continue;
      final path = _inspect(box, host, animations);
      if (path == null) {
        ejected.add(c);
        continue;
      }
      if (path.hidden) continue;
      final kept = <NativeGlassShape>[];
      var partlyClipped = false;
      for (final g in geometry) {
        final clip = path.clip;
        if (clip != null) {
          final visible = g.base.intersect(clip);
          if (visible.width <= 0 || visible.height <= 0) continue;
          if (!clip.inflate(0.5).contains(g.base.topLeft) ||
              !clip.inflate(0.5).contains(g.base.bottomRight)) {
            partlyClipped = true;
            break;
          }
        }
        kept.add((
          geometry: g,
          opacity: path.opacity == 1 ? null : path.opacity,
        ));
      }
      if (partlyClipped) {
        ejected.add(c);
        continue;
      }
      out.addAll(kept);
    }
    _listenTo(animations);
    for (final c in ejected) {
      _detach(c);
      c.eject();
    }
    if (ejected.isNotEmpty && _clients.isEmpty) onClientsChanged();
    return out;
  }

  void _listenTo(Set<Listenable> next) {
    for (final a in _animations.difference(next)) {
      a.removeListener(_changed);
    }
    for (final a in next.difference(_animations)) {
      a.addListener(_changed);
    }
    _animations = next;
  }

  /// The path from [box] up to [host], or null when the batch cannot draw
  /// [box]'s glass as its own view would (see [GlassBatch]).
  static _Path? _inspect(
    RenderBox box,
    RenderBox host,
    Set<Listenable> animations,
  ) {
    final rect = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    var hidden = false;
    var opacity = 1.0;
    Rect? clip;
    RenderObject child = box;
    var parent = box.parent;
    while (parent != null && !identical(parent, host)) {
      if (_paintsBeneath(parent)) return null;
      if (!parent.paintsChild(child)) hidden = true;
      if (parent is RenderOpacity) {
        opacity *= parent.opacity;
      } else if (parent is RenderAnimatedOpacity) {
        opacity *= parent.opacity.value;
        animations.add(parent.opacity);
      }
      final c = parent.describeApproximatePaintClip(child);
      if (c != null) {
        final g = MatrixUtils.transformRect(parent.getTransformTo(null), c);
        clip = clip == null ? g : clip.intersect(g);
      }
      if (_earlierSiblingOverlaps(parent, child, rect)) return null;
      child = parent;
      parent = parent.parent;
    }
    // Not below the batch in the render tree (an OverlayPortal child).
    if (parent == null) return null;
    final m = box.getTransformTo(host);
    const e = 1e-6;
    if (m.entry(0, 1).abs() > e ||
        m.entry(1, 0).abs() > e ||
        m.entry(3, 0).abs() > e ||
        m.entry(3, 1).abs() > e) {
      return null;
    }
    return (hidden: hidden, opacity: opacity, clip: clip);
  }

  /// Whether [o] paints something beneath its children.
  static bool _paintsBeneath(RenderObject o) => switch (o) {
    RenderDecoratedBox(:final decoration, :final position) =>
      position == DecorationPosition.background && !_isBlank(decoration),
    RenderPhysicalModel(:final color) => color.a > 0,
    RenderPhysicalShape(:final color) => color.a > 0,
    RenderCustomPaint(:final painter) => painter != null,
    RenderBackdropFilter() => true,
    _ => false,
  };

  /// Whether a child of [parent] painted before [child] overlaps [rect]
  /// (global): the batch's view would draw beneath it.
  static bool _earlierSiblingOverlaps(
    RenderObject parent,
    RenderObject child,
    Rect rect,
  ) {
    var before = true;
    var hit = false;
    parent.visitChildren((s) {
      if (!before || hit) return;
      if (identical(s, child)) {
        before = false;
        return;
      }
      if (s is! RenderBox || !s.attached || !s.hasSize || s.size.isEmpty) {
        return;
      }
      if (!parent.paintsChild(s)) return;
      final r = MatrixUtils.transformRect(
        s.getTransformTo(null),
        s.paintBounds,
      );
      final i = r.intersect(rect);
      if (i.width > 0.5 && i.height > 0.5) hit = true;
    });
    return hit;
  }

  @override
  void dispose() {
    _disposed = true;
    for (final a in _animations) {
      a.removeListener(_changed);
    }
    _animations = {};
    for (final e in _registries.entries) {
      e.value.removeListener(_changed);
    }
    _registries.clear();
    _clients.clear();
    super.dispose();
  }
}

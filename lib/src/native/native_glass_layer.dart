import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/glass_variant.dart';
import '../group/entry_geometry.dart';
import '../group/glass_entry.dart';
import '../group/glass_group_scope.dart';
import '../group/glass_press_geometry.dart';
import '../group/glass_registry.dart';
import 'glass_batch.dart';

/// How far the native view extends past the group on each side.
const double kNativeOverhang = 24;

/// Live native glass views above which a debug build warns once.
const int kNativeGroupWarningThreshold = 8;

/// One shape for a native view: an entry's geometry and the opacity of
/// the ancestors between it and the view (null: none; drawn opaque).
typedef NativeGlassShape = ({EntryGeometry geometry, double? opacity});

/// [registry]'s drawable entries for a group whose render box is [box],
/// recording each entry's drawn rect in group-local coordinates
/// (`GlassEntry.lastDrawnLocal`, used for removal ghosts). Null while
/// [box] is not laid out or not invertible.
List<EntryGeometry>? nativeGroupGeometry(
  RenderBox? box,
  GlassRegistry registry,
) {
  if (box == null || !box.attached || !box.hasSize) return null;
  final toGlobal = box.getTransformTo(null);
  final fromGlobal = Matrix4.tryInvert(toGlobal);
  if (fromGlobal == null) return null;
  final out = collectEntryGeometry(registry, toGlobal);
  for (final g in out) {
    g.entry.lastDrawnLocal = MatrixUtils.transformRect(fromGlobal, g.drawn);
  }
  return out;
}

/// The light SwiftUI's pressed `.interactive()` glass takes on, in native
/// mode: white added over the whole shape plus a Gaussian under the finger.
///
/// Measured on iOS 26.4 (`tool/fidelity/record_motion.sh`, `MODE=native`,
/// `press-capsule-photo-*`: a 200x56 regular capsule over the photo, held
/// 0.7 s off centre): SwiftUI's pressed frame minus this package's native
/// pressed frame (same Apple glass, same growth; the rest frames match
/// exactly), fitted inside the shape with the finger fixed. Light: lift
/// 10.2/255 + 5.0/255 Gaussian of σ 39 pt (rms 12.6 -> 4.0); dark: 12.6 +
/// 17.8, σ 43 pt (rms 20.5 -> 4.9). The lifts are asked about 10% above
/// those: SwiftUI adds 89% (light) and 93% (dark) of a `.plusLighter` white
/// inside the glass (measured). Clear glass is unmeasured and takes these
/// values.
abstract final class NativePressLight {
  /// White added over a pressed light-mode shape.
  static const double lightLift = 0.045;

  /// Peak of the light-mode Gaussian under the finger.
  static const double lightGlow = 0.020;

  /// White added over a pressed dark-mode shape.
  static const double darkLift = 0.053;

  /// Peak of the dark-mode Gaussian under the finger.
  static const double darkGlow = 0.070;

  /// The Gaussian's σ, points (fits: 39 light, 43 dark; the shader path's
  /// measured glow is 42).
  static const double sigma = 41;
}

/// Hosts SwiftUI's own Liquid Glass (a `GlassEffectContainer` with one
/// `.glassEffect` view per member) behind the group's content and keeps its
/// shapes, appearance and unions in sync.
///
/// When [batchable] (the group a `LiquidGlass` made for itself) and a
/// [GlassBatch] above can take it, the batch's view draws the glass and
/// this layer creates no view of its own.
class NativeGlassLayer extends StatefulWidget {
  /// Creates the layer.
  const NativeGlassLayer({
    super.key,
    required this.registry,
    required this.spacing,
    this.batchable = false,
    required this.child,
  });

  /// Members.
  final GlassRegistry registry;

  /// Container spacing.
  final double spacing;

  /// Whether an enclosing [GlassBatch] may draw this group's glass.
  final bool batchable;

  /// Group content.
  final Widget child;

  /// Native glass views alive now (debug builds only; 0 in release).
  @visibleForTesting
  static int get debugLiveCount => _NativeGlassViewState._live;

  /// Whether the too-many-views warning was printed; reset it in tests.
  @visibleForTesting
  static bool debugWarned = false;

  @override
  State<NativeGlassLayer> createState() => _NativeGlassLayerState();
}

class _NativeGlassLayerState extends State<NativeGlassLayer>
    implements NativeGlassBatchClient {
  /// The batch drawing this group's glass, or null when the group has a
  /// view of its own.
  NativeGlassBatch? _batch;

  /// Set when a batch gave this group back (it could not draw it
  /// faithfully); the group then keeps a view of its own for good.
  bool _ejected = false;

  @override
  GlassRegistry get registry => widget.registry;

  @override
  RenderBox? get groupBox =>
      mounted ? context.findRenderObject() as RenderBox? : null;

  @override
  void eject() {
    _batch = null;
    if (!_ejected && mounted) setState(() => _ejected = true);
  }

  void _syncBatch() {
    final next = widget.batchable && !_ejected
        ? GlassBatchScope.joinable(context)
        : null;
    if (identical(next, _batch)) return;
    _batch?.remove(this);
    _batch = next;
    next?.add(this);
  }

  @override
  void didUpdateWidget(NativeGlassLayer old) {
    super.didUpdateWidget(old);
    if (old.registry != widget.registry) {
      // Re-join (in build) so the batch listens to the new registry.
      _batch?.remove(this);
      _batch = null;
    }
  }

  @override
  void deactivate() {
    _batch?.remove(this);
    _batch = null;
    super.deactivate();
  }

  @override
  void dispose() {
    _batch?.remove(this);
    _batch = null;
    super.dispose();
  }

  List<NativeGlassShape>? _shapes() => nativeGroupGeometry(
    context.findRenderObject() as RenderBox?,
    widget.registry,
  )?.map<NativeGlassShape>((g) => (geometry: g, opacity: null)).toList();

  @override
  Widget build(BuildContext context) {
    _syncBatch();
    // Physical left/top/right/bottom on purpose: this is geometry, not
    // reading order, so it is correct in RTL too.
    // Passthrough: the group's child sees the group's own constraints, as
    // in the shader and material paths. The slot stays while batched, so
    // joining or leaving a batch never remounts the content.
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -kNativeOverhang,
          top: -kNativeOverhang,
          right: -kNativeOverhang,
          bottom: -kNativeOverhang,
          child: _batch != null
              ? const SizedBox.shrink()
              : NativeGlassView(
                  spacing: widget.spacing,
                  repaint: widget.registry,
                  shapes: _shapes,
                ),
        ),
        widget.child,
      ],
    );
  }
}

/// The platform view: one SwiftUI `GlassEffectContainer` drawing [shapes],
/// sized by its parent (a group or a batch plus [kNativeOverhang] on each
/// side).
class NativeGlassView extends StatefulWidget {
  /// Creates the view.
  const NativeGlassView({
    super.key,
    required this.spacing,
    required this.repaint,
    required this.shapes,
  });

  /// Container spacing.
  final double spacing;

  /// Notifies when [shapes] may have changed.
  final Listenable repaint;

  /// The shapes to draw (geometry in global coordinates); null skips the
  /// push.
  final List<NativeGlassShape>? Function() shapes;

  @override
  State<NativeGlassView> createState() => _NativeGlassViewState();
}

class _NativeGlassViewState extends State<NativeGlassView> {
  MethodChannel? _channel;
  bool _scheduled = false;

  /// The last payload sent, to skip identical pushes.
  Map<String, Object?>? _lastSent;

  /// Whether the glass renders in dark appearance (the platform brightness
  /// in scope, as the shader path uses).
  bool _dark = false;

  /// A stable id per entry (SwiftUI's `ForEach` identity), so a member keeps
  /// its id when others are added or removed.
  final Expando<int> _ids = Expando<int>('native glass id');
  int _nextId = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The group's resolved brightness. Without any (no MediaQuery above the
    // group) this draws light, deliberately: the appearance flag must always
    // go out, and light was this layer's behaviour without a brightness to
    // read. See GlassGroupScope.maybeBrightnessOf.
    final dark = GlassGroupScope.maybeBrightnessOf(context) == Brightness.dark;
    if (dark != _dark) {
      _dark = dark;
      _schedule();
    }
  }

  /// Native views alive now, counted in debug builds only.
  static int _live = 0;

  @override
  void initState() {
    super.initState();
    widget.repaint.addListener(_schedule);
    assert(() {
      _live++;
      if (_live > kNativeGroupWarningThreshold &&
          !NativeGlassLayer.debugWarned) {
        NativeGlassLayer.debugWarned = true;
        debugPrint(
          'adaptive_liquid_glass: $_live GlassGroups are on screen, each '
          'hosting its own native glass view, and every view is costly to '
          'create on iOS. A LiquidGlass outside a GlassGroup gets a group of '
          'its own: wrap repeated glass (list rows, chip rows, sheet content) '
          'in one shared GlassGroup or GlassBatch.',
        );
      }
      return true;
    }());
  }

  @override
  void didUpdateWidget(NativeGlassView old) {
    super.didUpdateWidget(old);
    if (old.repaint != widget.repaint) {
      old.repaint.removeListener(_schedule);
      widget.repaint.addListener(_schedule);
    }
    _schedule();
  }

  @override
  void dispose() {
    widget.repaint.removeListener(_schedule);
    assert(() {
      _live--;
      return true;
    }());
    super.dispose();
  }

  /// Coalesces changes into one push after the frame's layout.
  ///
  /// A change reported during post-frame callbacks (a member that moved
  /// without the group repainting) comes after layout and paint already, so
  /// it is pushed now instead of a frame later.
  void _schedule() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.postFrameCallbacks) {
      if (mounted) _push();
      return;
    }
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _push();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _push() {
    // Collected even before the platform view exists: that records where
    // each entry was drawn (see nativeGroupGeometry).
    final collected = widget.shapes();
    if (collected == null) return;
    final view = context.findRenderObject() as RenderBox?;
    if (view == null || !view.attached || !view.hasSize) return;
    final fromGlobal = Matrix4.tryInvert(view.getTransformTo(null));
    if (fromGlobal == null) return;
    final shapes = <Map<String, Object?>>[];
    // unionId objects become small indices (SwiftUI's glassEffectUnion id).
    final unions = <Object, int>{};
    for (final (:geometry, :opacity) in collected) {
      final r = MatrixUtils.transformRect(fromGlobal, geometry.drawn);
      final entry = geometry.entry;
      final glass = entry.glass;
      shapes.add({
        'id': _ids[entry] ??= _nextId++,
        'x': r.left,
        'y': r.top,
        'w': r.width,
        'h': r.height,
        'radius': geometry.radius,
        'capsule': geometry.circularCorners,
        'variant': glass.variant == GlassVariant.clear ? 1 : 0,
        'tint': glass.tintColor?.toARGB32(),
        'interactive': glass.isInteractive,
        'union': switch (entry.unionId) {
          null => null,
          final id => unions.putIfAbsent(id, () => unions.length),
        },
        'fills': _fills(entry, geometry.drawn),
        'glow': ?_glow(entry, geometry.drawn),
        'opacity': ?opacity,
      });
    }
    final channel = _channel;
    if (channel == null) return;
    final payload = <String, Object?>{
      'spacing': widget.spacing,
      'dark': _dark,
      'shapes': shapes,
    };
    final last = _lastSent;
    if (last != null && _samePayload(last, payload)) return;
    _lastSent = payload;
    channel.invokeMethod<void>('setShapes', payload);
  }

  /// [entry]'s press light as x, y (points, relative to the drawn glass
  /// [drawn], global), the Gaussian's peak and σ, and the lift over the
  /// whole shape; null when not pressed.
  ///
  /// SwiftUI's `.interactive()` glass lights up only under its own touches,
  /// which Flutter keeps, so the press's light is drawn here, scaled by
  /// [GlassPressGeometry.light]; see [NativePressLight].
  List<double>? _glow(GlassEntry entry, Rect drawn) {
    final press = entry.press;
    final touch = press.touch;
    final box = entry.box;
    if (touch == null || press.light <= 0 || box == null || !box.attached) {
      return null;
    }
    final p = MatrixUtils.transformPoint(box.getTransformTo(null), touch);
    return [
      p.dx - drawn.left,
      p.dy - drawn.top,
      (_dark ? NativePressLight.darkGlow : NativePressLight.lightGlow) *
          press.light,
      NativePressLight.sigma,
      (_dark ? NativePressLight.darkLift : NativePressLight.lightLift) *
          press.light,
    ];
  }

  /// [entry]'s content fills, flattened as x, y, w, h (points, relative to
  /// the drawn glass [drawn], global), opacity and style per fill.
  static List<double> _fills(GlassEntry entry, Rect drawn) => [
    for (final f in entry.fills)
      if (f.attached && f.hasSize)
        ...() {
          final r = MatrixUtils.transformRect(
            f.getTransformTo(null),
            Offset.zero & f.size,
          );
          return [
            r.left - drawn.left,
            r.top - drawn.top,
            r.width,
            r.height,
            f.opacity,
            f.style.index.toDouble(),
          ];
        }(),
  ];

  static bool _samePayload(Map<String, Object?> a, Map<String, Object?> b) {
    if (a['spacing'] != b['spacing'] || a['dark'] != b['dark']) return false;
    final sa = a['shapes']! as List<Map<String, Object?>>;
    final sb = b['shapes']! as List<Map<String, Object?>>;
    if (sa.length != sb.length) return false;
    for (var i = 0; i < sa.length; i++) {
      final x = sa[i];
      final y = sb[i];
      if (x.length != y.length) return false;
      for (final k in x.keys) {
        final a = x[k];
        final b = y[k];
        if (a is List<double> && b is List<double>) {
          if (!listEquals(a, b)) return false;
        } else if (a != b) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Glass is visual only: UIKit interaction is off, and the view must
    // never take part in Flutter hit testing or the gesture arena.
    return IgnorePointer(
      child: UiKitView(
        viewType: 'adaptive_liquid_glass/native_glass',
        creationParams: <String, Object?>{
          'spacing': widget.spacing,
          'dark': _dark,
          'shapes': const <Object?>[],
        },
        creationParamsCodec: const StandardMessageCodec(),
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
        onPlatformViewCreated: (id) {
          _channel = MethodChannel('adaptive_liquid_glass/native_glass_$id');
          _lastSent = null;
          _push();
        },
      ),
    );
  }
}

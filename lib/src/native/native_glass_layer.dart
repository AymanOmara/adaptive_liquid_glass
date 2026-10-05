import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/glass.dart';
import '../group/entry_geometry.dart';
import '../group/glass_group.dart';
import '../group/glass_registry.dart';

/// How far the native view extends past the group on each side.
const double kNativeOverhang = 24;

/// Hosts SwiftUI's own Liquid Glass (a `GlassEffectContainer` with one
/// `.glassEffect` view per member) behind the group's content and keeps its
/// shapes, appearance and unions in sync.
class NativeGlassLayer extends StatefulWidget {
  /// Creates the layer.
  const NativeGlassLayer({
    super.key,
    required this.registry,
    required this.spacing,
    required this.child,
  });

  /// Members.
  final GlassRegistry registry;

  /// Container spacing.
  final double spacing;

  /// Group content.
  final Widget child;

  @override
  State<NativeGlassLayer> createState() => _NativeGlassLayerState();
}

class _NativeGlassLayerState extends State<NativeGlassLayer> {
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

  @override
  void initState() {
    super.initState();
    widget.registry.addListener(_schedule);
  }

  @override
  void didUpdateWidget(NativeGlassLayer old) {
    super.didUpdateWidget(old);
    if (old.registry != widget.registry) {
      old.registry.removeListener(_schedule);
      widget.registry.addListener(_schedule);
    }
    _schedule();
  }

  @override
  void dispose() {
    widget.registry.removeListener(_schedule);
    super.dispose();
  }

  /// Coalesces registry changes into one push after the frame's layout.
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
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final toGlobal = box.getTransformTo(null);
    final fromGlobal = Matrix4.tryInvert(toGlobal);
    if (fromGlobal == null) return;
    final shapes = <Map<String, Object?>>[];
    // unionId objects become small indices (SwiftUI's glassEffectUnion id).
    final unions = <Object, int>{};
    for (final g in collectEntryGeometry(widget.registry, toGlobal)) {
      final local = MatrixUtils.transformRect(fromGlobal, g.drawn);
      // Same contract as the shader renderer: where the entry was drawn,
      // in group-local coordinates (used for removal ghosts). Recorded even
      // before the platform view exists.
      g.entry.lastDrawnLocal = local;
      final r = local.shift(const Offset(kNativeOverhang, kNativeOverhang));
      final glass = g.entry.glass;
      shapes.add({
        'id': _ids[g.entry] ??= _nextId++,
        'x': r.left,
        'y': r.top,
        'w': r.width,
        'h': r.height,
        'radius': g.radius,
        'capsule': g.circularCorners,
        'variant': glass.variant == GlassVariant.clear ? 1 : 0,
        'tint': glass.tintColor?.toARGB32(),
        'interactive': glass.isInteractive,
        'union': switch (g.entry.unionId) {
          null => null,
          final id => unions.putIfAbsent(id, () => unions.length),
        },
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
        if (x[k] != y[k]) return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Physical left/top/right/bottom on purpose: this is geometry, not
    // reading order, so it is correct in RTL too.
    // Passthrough: the group's child sees the group's own constraints, as
    // in the shader and material paths.
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -kNativeOverhang,
          top: -kNativeOverhang,
          right: -kNativeOverhang,
          bottom: -kNativeOverhang,
          // Glass is visual only: UIKit interaction is off, and the view must
          // never take part in Flutter hit testing or the gesture arena.
          child: IgnorePointer(
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
                _channel = MethodChannel(
                  'adaptive_liquid_glass/native_glass_$id',
                );
                _lastSent = null;
                _push();
              },
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

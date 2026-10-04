import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/glass.dart';
import '../core/glass_shape.dart';
import '../group/entry_geometry.dart';
import '../group/glass_registry.dart';

/// How far the native view extends past the group on each side.
const double kNativeOverhang = 24;

/// Hosts Apple's glass (`UIGlassContainerEffect` + `UIGlassEffect`) behind
/// the group's content and keeps its shapes in sync.
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
  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _push();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _push() {
    final channel = _channel;
    final box = context.findRenderObject() as RenderBox?;
    if (channel == null || box == null || !box.attached || !box.hasSize) {
      return;
    }
    final toGlobal = box.getTransformTo(null);
    final fromGlobal = Matrix4.tryInvert(toGlobal);
    if (fromGlobal == null) return;
    final shapes = <Map<String, Object?>>[];
    for (final g in collectEntryGeometry(widget.registry, toGlobal)) {
      final local = MatrixUtils.transformRect(fromGlobal, g.drawn);
      // Same contract as the shader renderer: where the entry was drawn,
      // in group-local coordinates (used for removal ghosts).
      g.entry.lastDrawnLocal = local;
      final r = local.shift(const Offset(kNativeOverhang, kNativeOverhang));
      final shape = g.entry.shape;
      final glass = g.entry.glass;
      shapes.add({
        'x': r.left,
        'y': r.top,
        'w': r.width,
        'h': r.height,
        'radius': g.radius,
        'capsule':
            shape is CapsuleGlassShape ||
            (shape is ConcentricGlassShape && g.entry.container == null),
        'variant': glass.variant == GlassVariant.clear ? 1 : 0,
        'tint': glass.tintColor?.toARGB32(),
        'interactive': glass.isInteractive,
      });
    }
    channel.invokeMethod<void>('setShapes', {
      'spacing': widget.spacing,
      'shapes': shapes,
    });
  }

  @override
  Widget build(BuildContext context) {
    // Physical left/top/right/bottom on purpose: this is geometry, not
    // reading order, so it is correct in RTL too.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -kNativeOverhang,
          top: -kNativeOverhang,
          right: -kNativeOverhang,
          bottom: -kNativeOverhang,
          child: UiKitView(
            viewType: 'adaptive_liquid_glass/native_glass',
            creationParams: <String, Object?>{
              'spacing': widget.spacing,
              'shapes': const <Object?>[],
            },
            creationParamsCodec: const StandardMessageCodec(),
            hitTestBehavior: PlatformViewHitTestBehavior.transparent,
            onPlatformViewCreated: (id) {
              _channel = MethodChannel(
                'adaptive_liquid_glass/native_glass_$id',
              );
              _push();
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}

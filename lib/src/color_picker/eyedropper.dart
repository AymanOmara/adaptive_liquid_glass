import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/glass_colors.dart';
import 'app_capture.dart';
import 'color_picker_metrics.dart';
import 'eyedropper_loupe.dart';

export 'eyedropper_loupe.dart' show EyedropperLoupe;

/// The colour of the pixel at [p] in an RGBA image [width] x [height]
/// pixels; a point off the image reads its nearest edge pixel.
Color colorAtPixel(ByteData rgba, int width, int height, Offset p) {
  final x = p.dx.floor().clamp(0, width - 1);
  final y = p.dy.floor().clamp(0, height - 1);
  final i = (y * width + x) * 4;
  return Color.fromARGB(
    rgba.getUint8(i + 3),
    rgba.getUint8(i),
    rgba.getUint8(i + 1),
    rgba.getUint8(i + 2),
  );
}

/// UIColorPickerViewController's eyedropper within the app: captures what
/// the app draws around [context], including embedded native views where
/// native capture supports them, then shows a loupe. Dragging moves the loupe,
/// letting go picks the pixel under its centre; a tap picks the pixel
/// tapped. Completes with that colour, or null when nothing could be
/// captured.
///
/// iOS includes native glass and UIKit subviews. Android includes ordinary
/// hybrid platform views on API 26+ while Flutter uses image/texture
/// composition or its usual opaque SurfaceView. API 36+ also captures
/// above-window Flutter surfaces in their real order and full-size direct
/// surfaces positioned through layout, with aligned loupe sampling. Custom
/// sizes, native view transforms, offsets through nested native containers,
/// offset/above-window surfaces on older Android versions and
/// unsupported hosts fall back to Flutter's outermost repaint boundary.
/// Other apps and separate system/protected
/// surfaces stay outside the capture.
Future<Color?> pickColorFromApp(BuildContext context) async {
  final view = View.of(context);
  RenderRepaintBoundary? boundary;
  context.visitAncestorElements((e) {
    final r = e.renderObject;
    if (r is RenderRepaintBoundary) boundary = r;
    return true;
  });
  final target = boundary;
  if (target != null && target.debugNeedsPaint) {
    await SchedulerBinding.instance.endOfFrame;
  }
  if (!context.mounted) return null;
  final native = await captureAppView(view);
  ui.Image image;
  double ratio;
  Matrix4 fromGlobal;
  if (native != null) {
    image = native.image;
    ratio = native.ratio;
    fromGlobal = Matrix4.translationValues(native.offset.dx, native.offset.dy, 0);
  } else {
    if (!context.mounted || target == null || !target.attached) return null;
    if (target.debugNeedsPaint) await SchedulerBinding.instance.endOfFrame;
    if (!context.mounted || !target.attached) return null;
    ratio = view.devicePixelRatio;
    final transform = Matrix4.tryInvert(target.getTransformTo(null));
    if (transform == null) return null;
    fromGlobal = transform;
    image = await target.toImage(pixelRatio: ratio);
  }
  final bytes = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  if (bytes == null || !context.mounted) {
    image.dispose();
    return null;
  }
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    image.dispose();
    return null;
  }
  final done = Completer<Color?>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _EyedropperLayer(
      image: image,
      bytes: bytes,
      ratio: ratio,
      fromGlobal: fromGlobal,
      onDone: (c) {
        entry.remove();
        // The loupe's last frame may still draw it.
        SchedulerBinding.instance.addPostFrameCallback((_) => image.dispose());
        done.complete(c);
      },
    ),
  );
  overlay.insert(entry);
  return done.future;
}

class _EyedropperLayer extends StatefulWidget {
  const _EyedropperLayer({
    required this.image,
    required this.bytes,
    required this.ratio,
    required this.fromGlobal,
    required this.onDone,
  });

  final ui.Image image;
  final ByteData bytes;
  final double ratio;
  final Matrix4 fromGlobal;
  final ValueChanged<Color?> onDone;

  @override
  State<_EyedropperLayer> createState() => _EyedropperLayerState();
}

class _EyedropperLayerState extends State<_EyedropperLayer> {
  Offset? _at;
  bool _done = false;

  /// [global] in the captured image's pixels.
  Offset _pixel(Offset global) {
    final local = MatrixUtils.transformPoint(widget.fromGlobal, global);
    return local * widget.ratio;
  }

  Color _colorAt(Offset global) => colorAtPixel(
    widget.bytes,
    widget.image.width,
    widget.image.height,
    _pixel(global),
  );

  void _finish(Offset global) {
    if (_done) return;
    _done = true;
    widget.onDone(_colorAt(global).withValues(alpha: 1));
  }

  @override
  Widget build(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    Offset toGlobal(Offset local) =>
        box != null && box.hasSize ? box.localToGlobal(local) : local;
    return LayoutBuilder(
      builder: (context, constraints) {
        final at = _at ?? constraints.biggest.center(Offset.zero);
        const d = ColorPickerMetrics.loupe;
        return Semantics(
          label: 'Eyedropper',
          onTap: () => _finish(toGlobal(at)),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onTapUp: (e) => _finish(e.globalPosition),
            onPanUpdate: (e) => setState(() => _at = (_at ?? at) + e.delta),
            onPanEnd: (_) => _finish(toGlobal(at)),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: GlassColors.transparent),
                ),
                Positioned(
                  left: at.dx - d / 2,
                  top: at.dy - d / 2,
                  width: d,
                  height: d,
                  child: EyedropperLoupe(
                    image: widget.image,
                    pixel: _pixel(toGlobal(at)),
                    color: _colorAt(toGlobal(at)).withValues(alpha: 1),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

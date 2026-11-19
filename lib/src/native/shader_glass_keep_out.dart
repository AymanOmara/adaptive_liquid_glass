import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'native_glass_layer.dart' show kNativeOverhang;

/// Global rects (logical px) where shader glass samples its backdrop.
///
/// On iOS, Flutter content overlapping a platform view is moved into an
/// overlay surface, where a BackdropFilter sees no backdrop and renders
/// grey. Native glass views trim their overhang so they never cover one of
/// these rects.
class ShaderGlassKeepOut extends ChangeNotifier {
  ShaderGlassKeepOut._();

  /// The shared registry.
  static final ShaderGlassKeepOut instance = ShaderGlassKeepOut._();

  final Map<Object, Rect> _rects = {};
  bool _pending = false;

  /// The current keep-out rects.
  Iterable<Rect> get rects => _rects.values;

  /// Sets (or with null, clears) [owner]'s rect. Listeners hear after the
  /// frame, so this is safe to call during paint.
  void report(Object owner, Rect? rect) {
    if (_rects[owner] == rect) return;
    if (rect == null) {
      _rects.remove(owner);
    } else {
      _rects[owner] = rect;
    }
    if (_pending) return;
    _pending = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _pending = false;
        notifyListeners();
      })
      ..ensureVisualUpdate();
  }
}

/// The overhang a native view around [group] may take on each side without
/// covering any [keepOut] rect that does not already overlap the group.
EdgeInsets nativeOverhangFor(
  Rect group,
  Iterable<Rect> keepOut, {
  double max = kNativeOverhang,
}) {
  var l = max, t = max, r = max, b = max;
  for (final k in keepOut) {
    if (group.overlaps(k)) continue; // unavoidable
    final grown = Rect.fromLTRB(
      group.left - l,
      group.top - t,
      group.right + r,
      group.bottom + b,
    );
    if (!grown.overlaps(k)) continue;
    // Overhang left on each side if that side alone is trimmed; -1 when
    // trimming that side cannot clear k.
    final cuts = [
      k.right <= group.left ? group.left - k.right : -1.0,
      k.bottom <= group.top ? group.top - k.bottom : -1.0,
      k.left >= group.right ? k.left - group.right : -1.0,
      k.top >= group.bottom ? k.top - group.bottom : -1.0,
    ];
    var best = 0;
    for (var i = 1; i < 4; i++) {
      if (cuts[i] > cuts[best]) best = i;
    }
    final v = cuts[best].clamp(0.0, max);
    switch (best) {
      case 0:
        if (v < l) l = v;
      case 1:
        if (v < t) t = v;
      case 2:
        if (v < r) r = v;
      default:
        if (v < b) b = v;
    }
  }
  return EdgeInsets.fromLTRB(l, t, r, b);
}

/// A Stack child placing [child] past its Stack on each side by the
/// overhang [nativeOverhangFor] allows.
class NativeOverhangSlot extends StatefulWidget {
  /// Creates the slot; must be a direct child of a Stack.
  const NativeOverhangSlot({super.key, required this.child});

  /// The native view.
  final Widget child;

  @override
  State<NativeOverhangSlot> createState() => _NativeOverhangSlotState();
}

class _NativeOverhangSlotState extends State<NativeOverhangSlot> {
  EdgeInsets _overhang = const EdgeInsets.all(kNativeOverhang);
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    ShaderGlassKeepOut.instance.addListener(_check);
  }

  @override
  void dispose() {
    ShaderGlassKeepOut.instance.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (!mounted) return;
    final probe = context.findRenderObject();
    final stack = probe?.parent;
    if (stack is! RenderBox || !stack.attached || !stack.hasSize) return;
    final group = MatrixUtils.transformRect(
      stack.getTransformTo(null),
      Offset.zero & stack.size,
    );
    final next = nativeOverhangFor(group, ShaderGlassKeepOut.instance.rects);
    if (next != _overhang) setState(() => _overhang = next);
  }

  void _onPaint() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _check();
    });
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: -_overhang.left,
    top: -_overhang.top,
    right: -_overhang.right,
    bottom: -_overhang.bottom,
    child: _PaintProbe(onPaint: _onPaint, child: widget.child),
  );
}

class _PaintProbe extends SingleChildRenderObjectWidget {
  const _PaintProbe({required this.onPaint, super.child});

  final VoidCallback onPaint;

  @override
  _RenderPaintProbe createRenderObject(BuildContext context) =>
      _RenderPaintProbe(onPaint);

  @override
  void updateRenderObject(BuildContext context, _RenderPaintProbe r) =>
      r.onPaint = onPaint;
}

class _RenderPaintProbe extends RenderProxyBox {
  _RenderPaintProbe(this.onPaint);

  VoidCallback onPaint;

  @override
  void paint(PaintingContext context, Offset offset) {
    onPaint();
    super.paint(context, offset);
  }
}

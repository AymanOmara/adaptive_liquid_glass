import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../shader/raster_snapshot_gate.dart';
import 'glass_entry.dart';
import 'glass_registry.dart';

/// See [GlassContentGlyphs].
class RenderGlassContentGlyphs extends RenderProxyBox {
  /// Creates the render object.
  RenderGlassContentGlyphs({
    required GlassEntry? entry,
    required this.registry,
    required bool enabled,
    required Color color,
    required double gain,
    required double reference,
    required bool vibrant,
    required double devicePixelRatio,
  }) : _entry = entry,
       _enabled = enabled,
       _color = color,
       _gain = gain,
       _reference = reference,
       _vibrant = vibrant,
       _devicePixelRatio = devicePixelRatio;

  /// The registry to refresh when the glyphs change.
  GlassRegistry? registry;

  GlassEntry? _entry;

  /// The enclosing glass.
  GlassEntry? get entry => _entry;
  set entry(GlassEntry? value) {
    if (value == _entry) return;
    if (attached) _entry?.glyphs.remove(this);
    _entry = value;
    if (attached) _entry?.glyphs.add(this);
    _changed();
  }

  bool _enabled;

  /// See [GlassContentGlyphs.enabled].
  bool get enabled => _enabled;
  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    _drop();
    super.markNeedsPaint();
    _changed();
  }

  Color _color;

  /// See [GlassContentGlyphs.color].
  Color get color => _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    _changed();
  }

  double _gain;

  /// See [GlassContentGlyphs.gain].
  double get gain => _gain;
  set gain(double value) {
    if (value == _gain) return;
    _gain = value;
    _changed();
  }

  double _reference;

  /// See [GlassContentGlyphs.reference].
  double get reference => _reference;
  set reference(double value) {
    if (value == _reference) return;
    _reference = value;
    _changed();
  }

  bool _vibrant;

  /// See [GlassContentGlyphs.vibrant].
  bool get vibrant => _vibrant;
  set vibrant(bool value) {
    if (value == _vibrant) return;
    _vibrant = value;
    _changed();
  }

  double _devicePixelRatio;

  /// The screen's pixel ratio, for the mask.
  double get devicePixelRatio => _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  static int _nextKey = 0;

  /// The glyphs' coverage, one byte per physical pixel, row by row; null
  /// until rasterised (native glass then draws nothing for this box).
  Uint8List? get mask => _mask;
  Uint8List? _mask;

  /// [mask]'s size in physical pixels.
  int get maskWidth => _maskWidth;
  int _maskWidth = 0;

  /// See [maskWidth].
  int get maskHeight => _maskHeight;
  int _maskHeight = 0;

  /// Unique per [mask]: native glass keeps masks by it, so each is sent
  /// once.
  int get maskKey => _maskKey;
  int _maskKey = 0;

  /// The rect [mask] covers, in this box's coordinates (the box plus the
  /// pad that takes glyphs overhanging it).
  Rect get maskRect => _maskRect;
  Rect _maskRect = Rect.zero;

  /// Whether native glass draws the glyphs now.
  bool get drawsNatively => _active && _mask != null;

  bool get _active =>
      _enabled &&
      _entry != null &&
      registry != null &&
      RasterSnapshotGate.instance.isOpen;

  final LayerHandle<OpacityLayer> _hidden = LayerHandle<OpacityLayer>();
  final LayerHandle<OffsetLayer> _glyphs = LayerHandle<OffsetLayer>();

  // Whether the mask must be rasterised again: a repaint of the child
  // reaches here (it is no repaint boundary), a move does not.
  bool _stale = true;
  Size? _maskBoxSize;
  // Counts rasterisations, so a slow read-back never replaces a newer one.
  int _generation = 0;
  Matrix4? _lastTransform;

  @override
  void markNeedsPaint() {
    _stale = true;
    super.markNeedsPaint();
  }

  void _drop() {
    _generation++;
    _mask = null;
    _maskKey = 0;
    _stale = true;
  }

  void _changed() {
    if (!attached) return;
    final r = registry;
    if (r == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached) r.markNeedsPaint();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _entry?.glyphs.add(this);
    RasterSnapshotGate.instance.addListener(markNeedsPaint);
    _changed();
  }

  @override
  void detach() {
    _entry?.glyphs.remove(this);
    RasterSnapshotGate.instance.removeListener(markNeedsPaint);
    registry?.markNeedsPaint();
    super.detach();
  }

  @override
  void dispose() {
    _hidden.layer = null;
    _glyphs.layer = null;
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    if (!_active || child.needsCompositing) {
      if (_mask != null) {
        _drop();
        _changed();
      }
      _hidden.layer = null;
      super.paint(context, offset);
      return;
    }
    if (_stale || _maskBoxSize != size) _rasterise(context, offset, child);
    // Flutter draws the glyphs until native glass has their first mask; a
    // later mask replaces the last one there a frame on.
    if (_mask == null) super.paint(context, offset);
    final t = getTransformTo(null);
    if (_lastTransform != t) _changed();
    _lastTransform = t;
  }

  void _rasterise(PaintingContext context, Offset offset, RenderBox child) {
    _stale = false;
    _maskBoxSize = size;
    // Glyphs overhang their slots (an icon font past its box, descenders).
    final pad = size.shortestSide / 2;
    final rect = (Offset.zero & size).inflate(pad);
    final glyphs = _glyphs.layer = OffsetLayer();
    _hidden.layer = context.pushOpacity(offset, 0, (context, offset) {
      context.pushLayer(
        glyphs,
        (context, offset) => context.paintChild(child, offset),
        offset,
      );
    }, oldLayer: _hidden.layer);
    final image = glyphs.toImageSync(rect, pixelRatio: _devicePixelRatio);
    final generation = ++_generation;
    image.toByteData(format: ui.ImageByteFormat.rawStraightRgba).then((data) {
      final w = image.width;
      final h = image.height;
      image.dispose();
      if (data == null || generation != _generation || !attached) return;
      final rgba = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final alpha = Uint8List(w * h);
      for (var i = 0; i < alpha.length; i++) {
        alpha[i] = rgba[i * 4 + 3];
      }
      _mask = alpha;
      _maskWidth = w;
      _maskHeight = h;
      _maskRect = rect;
      _maskKey = ++_nextKey;
      // The glyphs are unchanged: hide them without rasterising again.
      super.markNeedsPaint();
      _changed();
    });
  }
}

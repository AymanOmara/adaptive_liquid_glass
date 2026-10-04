import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Registry of content regions that glass may sample.
class GlassBackdropSources {
  GlassBackdropSources._();

  /// Shared instance.
  static final GlassBackdropSources instance = GlassBackdropSources._();

  final List<GlobalKey> _keys = [];
  final ValueNotifier<int> _revision = ValueNotifier(0);

  /// Bumps when sources are added or removed.
  ValueListenable<int> get revision => _revision;

  /// Attached boundaries.
  List<RenderRepaintBoundary> get boundaries => [
    for (final k in _keys)
      if (k.currentContext?.findRenderObject()
          case final RenderRepaintBoundary b when b.attached)
        b,
  ];

  void _add(GlobalKey k) {
    _keys.add(k);
    _revision.value++;
  }

  void _remove(GlobalKey k) {
    _keys.remove(k);
    _revision.value++;
  }
}

/// Marks content that glass floats over, enabling `GlassForeground`.
///
/// Costs a low-resolution GPU readback every 250 ms per glass group.
class GlassBackdropSource extends StatefulWidget {
  /// Creates a source.
  const GlassBackdropSource({super.key, required this.child});

  /// The content behind the glass.
  final Widget child;

  @override
  State<GlassBackdropSource> createState() => _GlassBackdropSourceState();
}

class _GlassBackdropSourceState extends State<GlassBackdropSource> {
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    GlassBackdropSources.instance._add(_key);
  }

  @override
  void dispose() {
    GlassBackdropSources.instance._remove(_key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(key: _key, child: widget.child);
}

/// Mean relative luminance of [globalRegion] within [boundary].
Future<double?> sampleLuminance(
  RenderRepaintBoundary boundary,
  Rect globalRegion,
) async {
  if (!boundary.attached || boundary.debugNeedsPaint) return null;
  const scale = 0.25;
  final toLocal = Matrix4.tryInvert(boundary.getTransformTo(null));
  if (toLocal == null) return null;
  final local = MatrixUtils.transformRect(
    toLocal,
    globalRegion,
  ).intersect(Offset.zero & boundary.size);
  if (local.isEmpty) return null;
  final ui.Image image = await boundary.toImage(pixelRatio: scale);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    final x0 = (local.left * scale).floor().clamp(0, image.width - 1);
    final y0 = (local.top * scale).floor().clamp(0, image.height - 1);
    final x1 = (local.right * scale).ceil().clamp(x0 + 1, image.width);
    final y1 = (local.bottom * scale).ceil().clamp(y0 + 1, image.height);
    var sum = 0.0;
    var n = 0;
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final i = (y * image.width + x) * 4;
        sum +=
            (0.2126 * data.getUint8(i) +
                0.7152 * data.getUint8(i + 1) +
                0.0722 * data.getUint8(i + 2)) /
            255;
        n++;
      }
    }
    return n == 0 ? null : sum / n;
  } finally {
    image.dispose();
  }
}

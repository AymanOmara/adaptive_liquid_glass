import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'glass_backdrop_sources.dart';

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
    GlassBackdropSources.instance.add(_key);
  }

  // Inactive elements have no render object to look up, so a source is
  // registered only while active.
  @override
  void activate() {
    super.activate();
    GlassBackdropSources.instance.add(_key);
  }

  @override
  void deactivate() {
    GlassBackdropSources.instance.remove(_key);
    super.deactivate();
  }

  @override
  void dispose() {
    GlassBackdropSources.instance.remove(_key);
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

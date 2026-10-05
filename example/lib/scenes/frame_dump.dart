import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Lossless frame dump of a motion view (Task 16b), `-dump x,y,w,h,frames`
/// (crop in physical px).
///
/// Once `<tmp>/motion-dump/start` exists, every frame's [boundary] (the whole
/// screen, at the origin: the glass shader samples in screen coordinates, so
/// it is rasterised full size and cropped afterwards) is captured with its
/// vsync time stamp. After `frames` frames the PNGs, `meta.json`
/// (`{"renderer", "times"}`, seconds) and `done` are written to the same
/// folder, as the SwiftUI host's `FrameDump` does.
class FrameDump {
  /// Parses [spec] and starts polling for the start file every frame.
  FrameDump(String spec, this.boundary, this.pixelRatio) {
    final v = spec.split(',').map(double.parse).toList();
    _crop = Rect.fromLTWH(v[0], v[1], v[2], v[3]);
    _count = v.length > 4 ? v[4].round() : 180;
    SchedulerBinding.instance.addPostFrameCallback(_frame);
  }

  /// The render object of the screen-sized `RepaintBoundary` to capture.
  final RenderRepaintBoundary? Function() boundary;

  /// Device pixel ratio of the screen.
  final double pixelRatio;

  late final Rect _crop;
  late final int _count;
  final Directory _dir = Directory('${Directory.systemTemp.path}/motion-dump');
  final List<ui.Image> _images = [];
  final List<double> _times = [];
  bool _armed = false;

  void _frame(Duration _) {
    final b = boundary();
    _armed = _armed || File('${_dir.path}/start').existsSync();
    if (_armed && b != null) {
      final full = b.toImageSync(pixelRatio: pixelRatio);
      final rec = ui.PictureRecorder();
      Canvas(rec).drawImageRect(
        full,
        _crop,
        Offset.zero & _crop.size,
        Paint()..filterQuality = FilterQuality.none,
      );
      final pic = rec.endRecording();
      _images.add(pic.toImageSync(_crop.width.round(), _crop.height.round()));
      pic.dispose();
      full.dispose();
      _times.add(
        SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds /
            1e6,
      );
      if (_images.length >= _count) {
        _write();
        return;
      }
    }
    SchedulerBinding.instance
      ..addPostFrameCallback(_frame)
      ..scheduleFrame();
  }

  Future<void> _write() async {
    for (var i = 0; i < _images.length; i++) {
      final png = await _images[i].toByteData(format: ui.ImageByteFormat.png);
      _images[i].dispose();
      final name = '${i + 1}'.padLeft(4, '0');
      await File('${_dir.path}/$name.png')
          .writeAsBytes(png!.buffer.asUint8List());
    }
    await File('${_dir.path}/meta.json')
        .writeAsString(jsonEncode({'renderer': 'flutter', 'times': _times}));
    await File('${_dir.path}/done').writeAsString('');
  }
}

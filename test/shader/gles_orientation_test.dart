import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Impeller's OpenGL ES backend stored render targets bottom-up before
// Flutter 3.46; impellerc defines IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED
// where it no longer does. A shader that samples the backdrop must flip
// only on the old engines, or it reads the backdrop upside down on
// Android GLES (verified on an emulator, Flutter 3.47).
const _guard =
    '#if defined(IMPELLER_TARGET_OPENGLES) && '
    '!defined(IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED)';

void main() {
  final shaders = Directory('shaders')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.frag'))
      .toList();

  test('every backdrop shader flips GLES only on pre-3.46 engines', () {
    for (final name in const [
      'liquid_glass.frag',
      'progressive_blur.frag',
      'tab_lens_content.frag',
      'tab_vibrancy.frag',
    ]) {
      final src = File('shaders/$name').readAsStringSync();
      expect(src, contains(_guard), reason: name);
    }
  });

  test('no shader flips on IMPELLER_TARGET_OPENGLES alone', () {
    for (final f in shaders) {
      final lines = f.readAsLinesSync();
      for (final line in lines) {
        final t = line.trim();
        if (!t.startsWith('#if') || !t.contains('IMPELLER_TARGET_OPENGLES')) {
          continue;
        }
        expect(t, _guard, reason: f.path);
      }
    }
  });
}

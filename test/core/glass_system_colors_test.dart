import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Light: sampled from text in gap-edge-hard-swiftui.png (iOS 26.4).
  // Dark: Apple's iOS 26 palette.
  test('purple, cyan and teal are iOS 26 values', () {
    const expected = {
      'purple': (GlassSystemColors.purple, 0xFFCB30E0, 0xFFDB34F2),
      'cyan': (GlassSystemColors.cyan, 0xFF00C0E8, 0xFF3CD3FE),
      'teal': (GlassSystemColors.teal, 0xFF00C3D0, 0xFF00D2E0),
    };
    for (final MapEntry(key: name, value: (c, light, dark))
        in expected.entries) {
      expect(c.color.toARGB32(), light, reason: '$name light');
      expect(c.darkColor.toARGB32(), dark, reason: '$name dark');
    }
  });
}

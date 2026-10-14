import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// Its own file: a plain `test` with no binding yet, as in an app's `main()`
// before `runApp`.
void main() {
  tearDown(GlassPlatform.instance.debugReset);

  test('initialize sets up the Flutter binding itself', () async {
    await AdaptiveLiquidGlass.initialize();
    expect(() => WidgetsBinding.instance, returnsNormally);
  });
}

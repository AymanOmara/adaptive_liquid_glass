import 'dart:async';

import 'package:adaptive_liquid_glass/src/navigation/progressive_blur_program.dart';
import 'package:adaptive_liquid_glass/src/tab_bar/tab_lens_program.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests run without the tab lens's content shader and the progressive
/// blur's (shader assets are not bundled in widget tests), so the tab bar
/// and the scroll edge use their fallbacks.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    TabLensProgram.instance.debugReset(skipLoad: true);
    ProgressiveBlurProgram.instance.debugReset(skipLoad: true);
  });
  await testMain();
}

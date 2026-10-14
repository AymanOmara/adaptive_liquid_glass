import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

CupertinoActivityIndicator _spinner(WidgetTester t) =>
    t.widget(find.byType(CupertinoActivityIndicator));

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('pulling reveals the spinner spokes with the progress', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(const GlassRefreshIndicator(progress: 0.4, refreshing: false)),
    );
    expect(_spinner(t).progress, 0.4);
    expect(_spinner(t).animating, isFalse);
  }, variant: ios);

  testWidgets('refreshing spins the fully revealed spinner', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(const GlassRefreshIndicator(progress: 0.4, refreshing: true)),
    );
    expect(_spinner(t).progress, 1);
    expect(_spinner(t).animating, isTrue);
  }, variant: ios);

  testWidgets("the spokes are UIKit's measured grey, light and dark", (
    t,
  ) async {
    shaderEnv();
    Future<int> spokes(Brightness brightness) async {
      await t.pumpWidget(
        plainHost(
          CupertinoTheme(
            data: CupertinoThemeData(brightness: brightness),
            child: const GlassRefreshIndicator(progress: 1, refreshing: true),
          ),
        ),
      );
      return _spinner(t).color!.toARGB32();
    }

    // iOS 26.4, `-controls refreshmotion` / `refreshmotiondark`.
    expect(await spokes(Brightness.light), 0xFF6E6E6E);
    expect(await spokes(Brightness.dark), 0xFF888893);
  }, variant: ios);
}

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/navigation/nav_bar_metrics.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  for (final (name, variant) in [('glass', ios), ('Material', android)]) {
    testWidgets('$name: an icon button is one labelled, tappable node', (
      t,
    ) async {
      shaderEnv();
      final s = t.ensureSemantics();
      await t.pumpWidget(
        appHost(
          GlassButton.icon(
            onPressed: () {},
            icon: CupertinoIcons.share,
            semanticLabel: 'Share',
          ),
        ),
      );
      expect(
        t.getSemantics(find.bySemanticsLabel('Share')),
        isSemantics(
          label: 'Share',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      s.dispose();
    }, variant: variant);
  }

  testWidgets('Material: loading is announced disabled and ignores taps', (
    t,
  ) async {
    shaderEnv();
    final s = t.ensureSemantics();
    var taps = 0;
    await t.pumpWidget(
      appHost(
        GlassButton(
          onPressed: () => taps++,
          loading: true,
          child: const Text('Save'),
        ),
      ),
    );
    await t.tap(find.byType(GlassButton), warnIfMissed: false);
    expect(taps, 0);
    expect(
      t.getSemantics(find.bySemanticsLabel('Save')),
      isSemantics(isButton: true, isEnabled: false, hasTapAction: false),
    );
    s.dispose();
  }, variant: android);

  testWidgets('bar items keep their size at large text sizes', (t) async {
    shaderEnv();
    await t.pumpWidget(
      MaterialApp(
        builder: (c, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 2,
          maxScaleFactor: 2,
          child: child!,
        ),
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => Navigator.of(c).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: GlassNavigationBar(
                    title: const Text('Detail'),
                    actions: [
                      GlassButton.icon(
                        onPressed: () {},
                        icon: CupertinoIcons.share,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(t.getSize(find.byType(GlassBackButton)), const Size(44, 44));
    expect(
      t.getSize(find.byType(GlassButton).last).width,
      NavBarMetrics.item.iconOnlyHeight + NavBarMetrics.item.iconOnlyExtraWidth,
    );
  }, variant: ios);
}

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('disabled: no tap, not interactive, a disabled button', (
    t,
  ) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(
      plainHost(const GlassButton(onPressed: null, child: Text('Save'))),
    );
    final glass = t.widget<LiquidGlass>(find.byType(LiquidGlass));
    expect(glass.onPressed, isNull);
    expect(glass.glass!.isInteractive, isFalse);
    expect(
      t.getSemantics(find.byType(GlassButton)),
      matchesSemantics(label: 'Save', isButton: true, hasEnabledState: true),
    );
    s.dispose();
  }, variant: ios);

  testWidgets('loading: indicator, taps ignored, label and loading read', (
    t,
  ) async {
    shaderEnv();
    final s = t.ensureSemantics();
    var taps = 0;
    await t.pumpWidget(
      plainHost(
        GlassButton(
          onPressed: () => taps++,
          loading: true,
          child: const Text('Save'),
        ),
      ),
    );
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    await t.tap(find.byType(GlassButton));
    expect(taps, 0);
    expect(
      t.getSemantics(find.byType(GlassButton)),
      matchesSemantics(
        label: 'Save',
        value: 'loading',
        isButton: true,
        hasEnabledState: true,
      ),
    );
    s.dispose();
  }, variant: ios);

  testWidgets('toggling loading does not change the size', (t) async {
    shaderEnv();
    Widget button(bool loading) => plainHost(
      GlassButton(
        onPressed: () {},
        loading: loading,
        child: const Text('Continue'),
      ),
    );
    await t.pumpWidget(button(false));
    final before = t.getSize(find.byType(GlassButton));
    await t.pumpWidget(button(true));
    expect(t.getSize(find.byType(GlassButton)), before);
  }, variant: ios);
}

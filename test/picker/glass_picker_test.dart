import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/menu/glass_menu_panel.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  String value = 'w';

  @override
  Widget build(BuildContext context) => GlassPicker<String>(
    items: const [
      GlassPickerItem(value: 'd', label: 'Day'),
      GlassPickerItem(value: 'w', label: 'Week'),
      GlassPickerItem(value: 'm', label: 'Month'),
    ],
    selected: value,
    onChanged: (v) => setState(() => value = v),
  );
}

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('shows the choice in blue; the menu checks it and picks', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(appHost(const _Harness()));
    final label = t.widget<Text>(find.text('Week'));
    expect(
      label.style!.color!.toARGB32(),
      GlassSystemColors.blue.color.toARGB32(),
    );
    final picker = t.getCenter(find.byType(GlassPicker<String>));
    await t.tap(find.text('Week'));
    await t.pumpAndSettle();
    final panel = t.getRect(find.byType(GlassMenuPanel));
    // Centred on the picker, its top 19 above the picker's centre.
    expect(panel.center.dx, moreOrLessEquals(picker.dx, epsilon: 1));
    expect(panel.top, moreOrLessEquals(picker.dy - 19, epsilon: 1));
    expect(find.byIcon(CupertinoIcons.checkmark_alt), findsOneWidget);
    await t.tap(find.text('Month'));
    await t.pumpAndSettle();
    expect(find.byType(GlassMenuPanel), findsNothing);
    expect(find.text('Month'), findsOneWidget);
  }, variant: ios);

  testWidgets('a picker at the screen edge keeps its menu on screen', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(
        const Align(
          alignment: AlignmentDirectional.centerEnd,
          child: _Harness(),
        ),
      ),
    );
    await t.tap(find.text('Week'));
    await t.pumpAndSettle();
    final panel = t.getRect(find.byType(GlassMenuPanel));
    final screen = t.view.physicalSize / t.view.devicePixelRatio;
    expect(panel.right, moreOrLessEquals(screen.width - 16, epsilon: 1));
  }, variant: ios);

  testWidgets('Material: a dropdown', (t) async {
    shaderEnv();
    await t.pumpWidget(appHost(const _Harness()));
    expect(find.byType(DropdownButton<String>), findsOneWidget);
  }, variant: android);
}

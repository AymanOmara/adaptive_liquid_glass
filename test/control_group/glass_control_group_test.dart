import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/button/glass_button_metrics_scope.dart';
import 'package:adaptive_liquid_glass/src/control_group/control_group_metrics.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _group({bool dividers = true, VoidCallback? onTap}) => GlassControlGroup(
  dividers: dividers,
  children: [
    GlassButton.icon(
      onPressed: onTap,
      icon: CupertinoIcons.chevron_up,
      semanticLabel: 'Previous',
    ),
    GlassButton.icon(
      onPressed: () {},
      icon: CupertinoIcons.chevron_down,
      semanticLabel: 'Next',
    ),
  ],
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('standalone: a 32-pt grey capsule, no glass; taps work', (
    t,
  ) async {
    shaderEnv();
    var taps = 0;
    await t.pumpWidget(plainHost(_group(onTap: () => taps++)));
    final size = t.getSize(find.byType(GlassControlGroup));
    expect(size.height, 32);
    expect(size.width, closeTo(2 * 34.33 + 1, 0.5));
    expect(find.byType(LiquidGlass), findsNothing);
    final box = t.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(GlassControlGroup),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect((box.decoration as ShapeDecoration).color!.toARGB32(), 0x33787880);
    final icon = t.widget<RichText>(
      find.descendant(
        of: find.byIcon(CupertinoIcons.chevron_up),
        matching: find.byType(RichText),
      ),
    );
    expect(icon.text.style!.color, const Color(0xFFFFFFFF));
    expect(icon.text.style!.fontSize, 20);
    await t.tap(find.bySemanticsLabel('Previous'));
    expect(taps, 1);
  }, variant: ios);

  testWidgets('dividers: false drops the line', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_group(dividers: false)));
    expect(
      t.getSize(find.byType(GlassControlGroup)).width,
      closeTo(2 * 34.33, 0.5),
    );
  }, variant: ios);

  testWidgets('in a bar: the 107.67 x 44 glass capsule', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        GlassButtonMetricsScope(
          metrics: ControlGroupMetrics.item,
          child: _group(dividers: false),
        ),
      ),
    );
    final size = t.getSize(find.byType(GlassControlGroup));
    expect(size.height, 44);
    expect(size.width, closeTo(107.67, 0.5));
    expect(find.byType(LiquidGlass), findsWidgets);
  }, variant: ios);

  testWidgets('menu style is one button that opens the items', (t) async {
    shaderEnv();
    var chosen = false;
    await t.pumpWidget(
      appHost(
        GlassControlGroup.menu(
          items: [
            GlassMenuItem(label: 'Copy', onSelected: () => chosen = true),
          ],
        ),
      ),
    );
    expect(find.byType(GlassMenuButton), findsOneWidget);
    await t.tap(find.bySemanticsLabel('More'));
    await t.pumpAndSettle();
    await t.tap(find.text('Copy'));
    await t.pumpAndSettle();
    expect(chosen, isTrue);
  }, variant: ios);

  testWidgets('Material path renders the buttons', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_group()));
    expect(find.byType(GlassControlGroup), findsOneWidget);
    expect(find.byType(GlassButton), findsNWidgets(2));
  }, variant: android);
}

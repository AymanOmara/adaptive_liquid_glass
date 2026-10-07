import 'package:adaptive_liquid_glass/src/core/glass_colors.dart';
import 'package:adaptive_liquid_glass/src/foreground/glass_foreground.dart';
import 'package:adaptive_liquid_glass/src/label/glass_label.dart';
import 'package:adaptive_liquid_glass/src/label/glass_label_layout.dart';
import 'package:adaptive_liquid_glass/src/label/label_metrics.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  const label = GlassLabel(
    title: Text('Favourites'),
    icon: Icon(CupertinoIcons.heart),
  );

  // The title's RichText (an Icon draws through a RichText too).
  Color textColor(WidgetTester t) => t
      .widget<RichText>(
        find.descendant(of: find.byType(Text), matching: find.byType(RichText)),
      )
      .text
      .style!
      .color!;
  Color iconColor(WidgetTester t) =>
      IconTheme.of(t.element(find.byType(Icon))).color!;

  testWidgets('icon at the start, title after, 6 apart', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(label));
    final icon = t.getRect(find.byType(Icon));
    final title = t.getRect(find.text('Favourites'));
    expect(icon.width, LabelMetrics.iconSize);
    expect(icon.right + LabelMetrics.iconGap, title.left);
  }, variant: ios);

  testWidgets('RTL: the icon is still at the start (the right)', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(label, direction: TextDirection.rtl));
    final icon = t.getRect(find.byType(Icon));
    final title = t.getRect(find.text('Favourites'));
    expect(title.right + LabelMetrics.iconGap, icon.left);
  }, variant: ios);

  testWidgets('iconOnly hides the title; titleOnly hides the icon', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const GlassLabel(
          title: Text('Favourites'),
          icon: Icon(CupertinoIcons.heart),
          layout: GlassLabelLayout.iconOnly,
        ),
      ),
    );
    expect(find.byType(Icon), findsOneWidget);
    expect(find.text('Favourites'), findsNothing);

    await t.pumpWidget(
      plainHost(
        const GlassLabel(
          title: Text('Favourites'),
          icon: Icon(CupertinoIcons.heart),
          layout: GlassLabelLayout.titleOnly,
        ),
      ),
    );
    expect(find.byType(Icon), findsNothing);
    expect(find.text('Favourites'), findsOneWidget);
  }, variant: ios);

  testWidgets('.text builds from a string and an IconData', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        GlassLabel.text(text: 'Favourites', icon: CupertinoIcons.heart),
      ),
    );
    expect(find.text('Favourites'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.heart), findsOneWidget);
  }, variant: ios);

  testWidgets('the colour follows GlassForeground', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const GlassForeground(
          backgroundBrightness: Brightness.dark,
          child: label,
        ),
      ),
    );
    expect(textColor(t), GlassColors.labelOnDark);
    expect(iconColor(t), GlassColors.labelOnDark);

    await t.pumpWidget(
      plainHost(
        const GlassForeground(
          backgroundBrightness: Brightness.light,
          child: label,
        ),
      ),
    );
    expect(textColor(t), GlassColors.labelOnLight);
    expect(iconColor(t), GlassColors.labelOnLight);
  }, variant: ios);

  testWidgets('an explicit Text or Icon colour wins; so does color', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const GlassForeground(
          backgroundBrightness: Brightness.dark,
          child: GlassLabel(
            title: Text(
              'Favourites',
              style: TextStyle(color: Color(0xFFFF0000)),
            ),
            icon: Icon(CupertinoIcons.heart, color: Color(0xFF00FF00)),
          ),
        ),
      ),
    );
    expect(textColor(t), const Color(0xFFFF0000));
    expect(t.widget<Icon>(find.byType(Icon)).color, const Color(0xFF00FF00));

    await t.pumpWidget(
      plainHost(
        const GlassForeground(
          backgroundBrightness: Brightness.dark,
          child: GlassLabel(
            title: Text('Favourites'),
            icon: Icon(CupertinoIcons.heart),
            color: Color(0xFF0000FF),
          ),
        ),
      ),
    );
    expect(textColor(t), const Color(0xFF0000FF));
    expect(iconColor(t), const Color(0xFF0000FF));
  }, variant: ios);

  testWidgets('a surrounding text colour is kept', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const GlassForeground(
          backgroundBrightness: Brightness.dark,
          child: DefaultTextStyle(
            style: TextStyle(color: GlassColors.white),
            child: label,
          ),
        ),
      ),
    );
    expect(textColor(t), GlassColors.white);
  }, variant: ios);

  testWidgets('one node, named by the title; icon-only keeps the name', (
    t,
  ) async {
    shaderEnv();
    final semantics = t.ensureSemantics();
    await t.pumpWidget(plainHost(label));
    expect(find.bySemanticsLabel('Favourites'), findsOneWidget);

    await t.pumpWidget(
      plainHost(
        const GlassLabel(
          title: Text('Favourites'),
          icon: Icon(CupertinoIcons.heart),
          layout: GlassLabelLayout.iconOnly,
        ),
      ),
    );
    expect(find.bySemanticsLabel('Favourites'), findsOneWidget);

    await t.pumpWidget(
      plainHost(
        const GlassLabel(
          title: Text('Favourites'),
          icon: Icon(CupertinoIcons.heart),
          semanticLabel: 'Liked',
        ),
      ),
    );
    expect(find.bySemanticsLabel('Liked'), findsOneWidget);
    expect(find.bySemanticsLabel('Favourites'), findsNothing);
    semantics.dispose();
  }, variant: ios);

  testWidgets('Material: 18 icon, 8 gap, the theme\'s text colour', (t) async {
    shaderEnv();
    await t.pumpWidget(appHost(label));
    final icon = t.getRect(find.byType(Icon));
    final title = t.getRect(find.text('Favourites'));
    expect(icon.width, LabelMetrics.materialIconSize);
    expect(icon.right + LabelMetrics.materialIconGap, title.left);
    final themed = DefaultTextStyle.of(
      t.element(find.byType(GlassLabel)),
    ).style.color;
    expect(textColor(t), themed);
  }, variant: android);
}

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_colors.dart';
import 'package:adaptive_liquid_glass/src/list/form_metrics.dart';
import 'package:adaptive_liquid_glass/src/list/list_metrics.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show MaterialApp, Scaffold;
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

/// The form under a MediaQuery with a 62-pt safe top and [keyboard].
Widget _host(Widget form, {double keyboard = 0}) => MediaQuery(
  data: MediaQueryData(
    size: const Size(402, 874),
    padding: const EdgeInsets.only(top: 62, bottom: 34),
    viewInsets: EdgeInsets.only(bottom: keyboard),
  ),
  child: Directionality(textDirection: TextDirection.ltr, child: form),
);

GlassListSection _section(String row, {String? header, String? footer}) =>
    GlassListSection(
      header: header == null ? null : Text(header),
      footer: footer == null ? null : Text(footer),
      children: [GlassListTile(title: Text(row))],
    );

GlassForm _form() => GlassForm(
  children: [
    _section('Name', header: 'Account', footer: 'Used to sign in.'),
    _section('Notifications', header: 'Preferences'),
    _section('Sign Out'),
  ],
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('platters spaced as SwiftUI Form: 76 across captions, '
      'else 35; first under safe top + 42.33', (t) async {
    shaderEnv();
    await t.pumpWidget(_host(_form()));
    final rows = find.byType(GlassListTile);
    Rect at(int i) => t.getRect(rows.at(i));
    // The first platter: safe top, the top inset, then the header (natively
    // 42.33 below safe top with SF's 16-pt caption line).
    final header = t.getRect(find.text('Account'));
    expect(header.top, closeTo(62 + FormMetrics.topInset, 0.1));
    expect(at(0).top, closeTo(header.bottom + ListMetrics.headerGap, 0.1));
    // Across a footer and a header (76 natively): footer, 24, header.
    expect(
      t.getRect(find.text('Preferences')).top -
          t.getRect(find.text('Used to sign in.')).bottom,
      closeTo(FormMetrics.captionSectionGap, 0.1),
    );
    expect(at(1).top - at(0).bottom, closeTo(76, 0.5));
    // Into a headerless section: 35.
    expect(at(2).top - at(1).bottom, closeTo(FormMetrics.sectionGap, 0.1));
    // The grouped background fills the form.
    final fill = t.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(GlassForm),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(fill.color.toARGB32(), GlassColors.formBackground.color.toARGB32());
  }, variant: ios);

  testWidgets('the keyboard replaces the bottom safe area', (t) async {
    shaderEnv();
    EdgeInsets padding() =>
        t.widget<ListView>(find.byType(ListView)).padding! as EdgeInsets;
    await t.pumpWidget(_host(_form()));
    expect(padding().bottom, FormMetrics.bottomInset + 34);
    await t.pumpWidget(_host(_form(), keyboard: 300));
    expect(padding().bottom, FormMetrics.bottomInset + 300);
  }, variant: ios);

  testWidgets('Material: even 24-pt gaps between cards', (t) async {
    shaderEnv();
    await t.pumpWidget(MaterialApp(home: Scaffold(body: _form())));
    final gaps = find.descendant(
      of: find.byType(ListView),
      matching: find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == FormMetrics.materialSectionGap,
      ),
    );
    expect(gaps, findsNWidgets(2));
  }, variant: android);
}

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/navigation/nav_bar_metrics.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _inline() => const MaterialApp(
  home: Scaffold(
    extendBodyBehindAppBar: true,
    appBar: GlassNavigationBar(
      title: Text('Inbox'),
      subtitle: Text('3 unread'),
    ),
    body: SizedBox(),
  ),
);

Widget _large() => MaterialApp(
  home: Scaffold(
    body: CustomScrollView(
      slivers: [
        const SliverGlassNavigationBar(
          largeTitle: Text('Inbox'),
          subtitle: Text('3 unread'),
        ),
        SliverList.builder(
          itemCount: 60,
          itemBuilder: (_, i) => SizedBox(height: 44, child: Text('Row $i')),
        ),
      ],
    ),
  ),
);

void main() {
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('inline: the subtitle sits under the title', (t) async {
    shaderEnv();
    await t.pumpWidget(_inline());
    final title = t.getRect(find.text('Inbox'));
    final sub = t.getRect(find.text('3 unread'));
    expect(sub.top, greaterThanOrEqualTo(title.bottom - 1));
    expect(sub.center.dx, closeTo(title.center.dx, 1));
    expect(
      t
          .widget<DefaultTextStyle>(
            find
                .ancestor(
                  of: find.text('3 unread'),
                  matching: find.byType(DefaultTextStyle),
                )
                .first,
          )
          .style
          .fontSize,
      NavBarMetrics.subtitleFontSize,
    );
  }, variant: ios);

  testWidgets('large title: the subtitle sits under it, taller header', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(_large());
    final title = t.getRect(find.text('Inbox').first);
    final sub = t.getRect(find.text('3 unread').first);
    expect(sub.top, greaterThanOrEqualTo(title.bottom - 1));
    expect(sub.left, closeTo(title.left, 1));
    final headerBottom = t.getTopLeft(find.text('Row 0')).dy;
    expect(
      headerBottom,
      greaterThan(
        NavBarMetrics.barHeight + NavBarMetrics.largeTitleHeight + 10,
      ),
    );
  }, variant: ios);

  testWidgets('Material: both bars stack the subtitle in the title', (t) async {
    shaderEnv();
    await t.pumpWidget(_inline());
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('3 unread'), findsOneWidget);
    expect(
      t.getRect(find.text('3 unread')).top,
      greaterThanOrEqualTo(t.getRect(find.text('Inbox')).bottom - 1),
    );
    await t.pumpWidget(_large());
    expect(find.text('3 unread'), findsWidgets);
  }, variant: android);
}

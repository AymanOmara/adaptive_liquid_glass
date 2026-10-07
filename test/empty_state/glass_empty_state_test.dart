import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/empty_state/empty_state_metrics.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

/// A constable callback for action buttons in const trees.
void _noop() {}

/// The effective style [text] renders with.
TextStyle _style(WidgetTester t, String text) => t
    .widget<RichText>(
      find.descendant(of: find.text(text), matching: find.byType(RichText)),
    )
    .text
    .style!;

const _state = GlassEmptyState(
  icon: Icon(CupertinoIcons.tray),
  title: Text('No Mail'),
  description: Text('New messages you receive will appear here.'),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('icon, title, description, actions; centred in order', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const GlassEmptyState(
          icon: Icon(CupertinoIcons.tray),
          title: Text('No Mail'),
          description: Text('New messages you receive will appear here.'),
          actions: [
            GlassButton(onPressed: _noop, child: Text('Refresh')),
            GlassButton(onPressed: _noop, child: Text('Mailboxes')),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.tray), findsOneWidget);
    expect(
      t.getSize(find.byIcon(CupertinoIcons.tray)).width,
      EmptyStateMetrics.iconSize,
    );
    final icon = t.getCenter(find.byIcon(CupertinoIcons.tray));
    final title = t.getCenter(find.text('No Mail'));
    final description = t.getCenter(
      find.text('New messages you receive will appear here.'),
    );
    final firstAction = t.getCenter(find.text('Refresh'));
    final secondAction = t.getCenter(find.text('Mailboxes'));
    expect(icon.dy, lessThan(title.dy));
    expect(title.dy, lessThan(description.dy));
    expect(description.dy, lessThan(firstAction.dy));
    // All centred on the page's middle line, and on each other.
    expect(title.dx, closeTo(400, 0.1));
    expect(icon.dx, closeTo(title.dx, 0.1));
    expect(description.dx, closeTo(title.dx, 0.1));
    // Actions stack vertically with actionSpacing between them.
    final buttonHeight = t.getSize(find.byType(LiquidGlass).first).height;
    expect(
      secondAction.dy - firstAction.dy,
      closeTo(buttonHeight + EmptyStateMetrics.actionSpacing, 0.5),
    );
    expect(secondAction.dx, closeTo(title.dx, 0.5));
  }, variant: ios);

  testWidgets('the title is titleSize bold on the label colour', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_state));
    final title = _style(t, 'No Mail');
    expect(title.fontSize, EmptyStateMetrics.titleSize);
    expect(title.fontWeight, EmptyStateMetrics.titleWeight);
    expect(title.color!.toARGB32(), CupertinoColors.label.color.toARGB32());
    final description = _style(t, 'New messages you receive will appear here.');
    expect(description.fontSize, EmptyStateMetrics.descriptionSize);
    expect(
      description.color!.toARGB32(),
      CupertinoColors.secondaryLabel.color.toARGB32(),
    );
  }, variant: ios);

  testWidgets('search: "No Results for “query”", or just "No Results"', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(plainHost(GlassEmptyState.search(query: 'kiwi')));
    expect(find.byIcon(CupertinoIcons.search), findsOneWidget);
    expect(find.text('No Results for \u201Ckiwi\u201D'), findsOneWidget);
    expect(find.text(GlassEmptyState.searchDescription), findsOneWidget);
    await t.pumpWidget(plainHost(GlassEmptyState.search()));
    expect(find.text('No Results'), findsOneWidget);
    expect(find.textContaining('kiwi'), findsNothing);
  }, variant: ios);

  testWidgets('the title is a header; the icon is not announced', (t) async {
    shaderEnv();
    final handle = t.ensureSemantics();
    await t.pumpWidget(plainHost(_state));
    expect(
      t.getSemantics(find.text('No Mail')),
      isSemantics(isHeader: true, label: 'No Mail'),
    );
    handle.dispose();
  }, variant: ios);

  testWidgets('right to left: still centred, no overflow', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_state, direction: TextDirection.rtl));
    expect(t.takeException(), isNull);
    final title = t.getCenter(find.text('No Mail'));
    final description = t.getCenter(
      find.text('New messages you receive will appear here.'),
    );
    expect(title.dx, closeTo(400, 0.1));
    expect(description.dx, closeTo(title.dx, 0.1));
    expect(description.dy, greaterThan(title.dy));
  }, variant: ios);

  testWidgets('Reduce Motion: nothing animates; the column stands', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: _state,
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
    expect(t.takeException(), isNull);
    final title = t.getCenter(find.text('No Mail'));
    expect(title.dx, closeTo(400, 0.1));
    final description = t.getCenter(
      find.text('New messages you receive will appear here.'),
    );
    expect(description.dx, closeTo(title.dx, 0.1));
  }, variant: ios);

  testWidgets('an action button tap fires its callback', (t) async {
    shaderEnv();
    var taps = 0;
    await t.pumpWidget(
      plainHost(
        GlassEmptyState(
          title: const Text('No Mail'),
          actions: [
            GlassButton(onPressed: () => taps++, child: const Text('Refresh')),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Refresh'));
    await t.pump();
    expect(taps, 1);
    // SwiftUI's actions are small buttons unless the app sizes them.
    expect(
      GlassControlSizeScope.maybeOf(t.element(find.text('Refresh'))),
      EmptyStateMetrics.actionsControlSize,
    );
  }, variant: ios);

  testWidgets('Material: titleLarge title, bodyMedium description', (t) async {
    shaderEnv();
    TextStyle? titleLarge;
    TextStyle? bodyMedium;
    Color? onSurfaceVariant;
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        ),
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) {
                titleLarge = Theme.of(context).textTheme.titleLarge;
                bodyMedium = Theme.of(context).textTheme.bodyMedium;
                onSurfaceVariant = Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant;
                return _state;
              },
            ),
          ),
        ),
      ),
    );
    expect(_style(t, 'No Mail').fontSize, titleLarge!.fontSize);
    expect(_style(t, 'No Mail').fontWeight, titleLarge!.fontWeight);
    final description = _style(t, 'New messages you receive will appear here.');
    expect(description.fontSize, bodyMedium!.fontSize);
    expect(description.color!.toARGB32(), onSurfaceVariant!.toARGB32());
    expect(find.byType(Card), findsNothing);
    expect(find.byType(LiquidGlass), findsNothing);
  }, variant: android);
}

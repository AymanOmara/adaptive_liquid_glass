import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/search/search_metrics.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _app({
  GlassSearchController? controller,
  List<GlassSearchSuggestion> Function(BuildContext, GlassSearchController)?
  suggestions,
  List<String>? scopes,
  GlassSearchablePlacement placement = GlassSearchablePlacement.bottom,
  TextDirection direction = TextDirection.ltr,
  bool reduceMotion = false,
  ValueChanged<String>? onChanged,
  ValueChanged<int>? onScopeChanged,
}) => MaterialApp(
  home: Scaffold(
    body: Directionality(
      textDirection: direction,
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: GlassSearchable(
            controller: controller,
            onChanged: onChanged,
            onScopeChanged: onScopeChanged,
            suggestionsBuilder: suggestions,
            scopes: scopes,
            placement: placement,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('tapping the field reveals Cancel; tapping it dismisses', (
    t,
  ) async {
    shaderEnv();
    final controller = GlassSearchController();
    addTearDown(controller.dispose);
    final changes = <String>[];
    await t.pumpWidget(_app(controller: controller, onChanged: changes.add));
    expect(controller.isActive, false);
    expect(find.byType(SearchCancelButton), findsNothing);
    await t.tap(find.byType(CupertinoTextField));
    await t.pumpAndSettle();
    expect(controller.isActive, true);
    expect(find.byType(SearchCancelButton), findsOneWidget);
    await t.enterText(find.byType(CupertinoTextField), 'glass');
    await t.pump();
    expect(controller.text, 'glass');
    await t.tap(find.byType(SearchCancelButton));
    await t.pumpAndSettle();
    expect(controller.text, '');
    expect(controller.isActive, false);
    expect(find.byType(SearchCancelButton), findsNothing);
    expect(changes.last, '');
  }, variant: ios);

  testWidgets('activating the controller from outside reveals Cancel', (
    t,
  ) async {
    shaderEnv();
    final controller = GlassSearchController();
    addTearDown(controller.dispose);
    await t.pumpWidget(_app(controller: controller));
    expect(find.byType(SearchCancelButton), findsNothing);
    controller.activate();
    await t.pumpAndSettle();
    expect(find.byType(SearchCancelButton), findsOneWidget);
  }, variant: ios);

  testWidgets('suggestions show when active; a tap fills the field', (t) async {
    shaderEnv();
    final controller = GlassSearchController();
    addTearDown(controller.dispose);
    var picked = 0;
    await t.pumpWidget(
      _app(
        controller: controller,
        suggestions: (context, search) => [
          GlassSearchSuggestion(
            title: const Text('First'),
            onSelected: () => picked++,
          ),
          const GlassSearchSuggestion(title: Text('Second')),
        ],
      ),
    );
    expect(find.byType(GlassSearchSuggestionRow), findsNothing);
    await t.tap(find.byType(CupertinoTextField));
    await t.pumpAndSettle();
    expect(find.byType(GlassSearchSuggestionRow), findsNWidgets(2));
    await t.tap(find.byType(GlassSearchSuggestionRow).first);
    await t.pump();
    expect(controller.text, 'First');
    expect(picked, 1);
  }, variant: ios);

  testWidgets('scopes show a segmented control only while active', (t) async {
    shaderEnv();
    final controller = GlassSearchController();
    addTearDown(controller.dispose);
    var scope = -1;
    await t.pumpWidget(
      _app(
        controller: controller,
        scopes: const ['All', 'Mine'],
        onScopeChanged: (i) => scope = i,
      ),
    );
    expect(find.byType(GlassSegmentedControl<int>), findsNothing);
    await t.tap(find.byType(CupertinoTextField));
    await t.pumpAndSettle();
    expect(find.byType(GlassSegmentedControl<int>), findsOneWidget);
    await t.tap(find.text('Mine'));
    await t.pumpAndSettle();
    expect(scope, 1);
    expect(controller.scopeIndex, 1);
  }, variant: ios);

  testWidgets('RTL: Cancel slides out to the left of the field', (t) async {
    shaderEnv();
    await t.pumpWidget(_app(direction: TextDirection.rtl));
    await t.tap(find.byType(CupertinoTextField));
    await t.pumpAndSettle();
    expect(
      t.getCenter(find.byType(SearchCancelButton)).dx,
      lessThan(t.getCenter(find.byType(GlassSearchField)).dx),
    );
  }, variant: ios);

  testWidgets('LTR: Cancel slides out to the right of the field', (t) async {
    shaderEnv();
    await t.pumpWidget(_app());
    await t.tap(find.byType(CupertinoTextField));
    await t.pumpAndSettle();
    expect(
      t.getCenter(find.byType(SearchCancelButton)).dx,
      greaterThan(t.getCenter(find.byType(GlassSearchField)).dx),
    );
  }, variant: ios);

  testWidgets('Reduce Motion: Cancel appears without the spring', (t) async {
    shaderEnv();
    await t.pumpWidget(_app(reduceMotion: true));
    await t.tap(find.byType(CupertinoTextField));
    await t.pump();
    expect(find.byType(SearchCancelButton), findsOneWidget);
    expect(
      t.getSize(find.byType(SearchCancelButton)).width,
      greaterThanOrEqualTo(SearchMetrics.cancelMinWidth),
    );
  }, variant: ios);

  testWidgets('semantics: Cancel and a suggestion row are buttons', (t) async {
    shaderEnv();
    final semantics = t.ensureSemantics();
    await t.pumpWidget(
      _app(
        suggestions: (context, search) => const [
          GlassSearchSuggestion(title: Text('First')),
        ],
      ),
    );
    await t.tap(find.byType(CupertinoTextField));
    await t.pumpAndSettle();
    expect(
      t.getSemantics(find.byType(SearchCancelButton)),
      matchesSemantics(isButton: true, label: 'Cancel', hasTapAction: true),
    );
    expect(
      t.getSemantics(find.byType(GlassSearchSuggestionRow).first),
      matchesSemantics(isButton: true, hasTapAction: true),
    );
    semantics.dispose();
  }, variant: ios);

  testWidgets('Material: a search anchor with a scope button', (t) async {
    shaderEnv();
    await t.pumpWidget(_app(scopes: const ['All', 'Mine']));
    // SearchAnchor.bar builds a private SearchAnchor subclass.
    expect(find.bySubtype<SearchAnchor>(), findsOneWidget);
    expect(find.byType(SegmentedButton<int>), findsOneWidget);
  }, variant: android);
}

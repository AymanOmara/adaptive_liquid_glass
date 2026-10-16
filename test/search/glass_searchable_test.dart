import 'dart:math' as math;

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_colors.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/search/search_metrics.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringSimulation;
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
  double topPadding = 0,
  ValueChanged<String>? onChanged,
  ValueChanged<int>? onScopeChanged,
  Widget child = const SizedBox.expand(),
}) => MaterialApp(
  home: Scaffold(
    body: Directionality(
      textDirection: direction,
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            padding: EdgeInsets.only(top: topPadding),
          ),
          child: GlassSearchable(
            controller: controller,
            onChanged: onChanged,
            onScopeChanged: onScopeChanged,
            suggestionsBuilder: suggestions,
            scopes: scopes,
            placement: placement,
            child: child,
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

  test("the close button's reveal is the fitted one", () {
    // Fitted to three SwiftUI recordings (iOS 26.4), rms 1.95 pt.
    expect(SearchMetrics.revealSplit, 0.13);
    expect(SearchMetrics.revealScale, 0.32);
    final spring = SearchMetrics.activation;
    // swiftUISpring(response: 0.53, dampingFraction: 0.69), unit mass.
    expect(spring.stiffness, closeTo(math.pow(2 * math.pi / 0.53, 2), 1e-6));
    expect(spring.damping, closeTo(4 * math.pi * 0.69 / 0.53, 1e-6));
  });

  testWidgets('the field narrows first, then the button grows past its '
      'size and settles', (t) async {
    shaderEnv();
    final controller = GlassSearchController();
    addTearDown(controller.dispose);
    await t.pumpWidget(_app(controller: controller));
    controller.activate();
    await t.pump();
    final simulation = SpringSimulation(SearchMetrics.activation, 0, 1, 0);
    double width() {
      final button = find.byType(SearchCancelButton);
      return t.getBottomRight(button).dx - t.getTopLeft(button).dx;
    }

    var elapsed = Duration.zero;
    var widest = 0.0;
    for (var frame = 1; frame <= 60; frame++) {
      await t.pump(const Duration(milliseconds: 16));
      elapsed += const Duration(milliseconds: 16);
      final v = simulation.x(elapsed.inMicroseconds / 1e6);
      if (v > SearchMetrics.revealSplit) {
        final grow =
            (v - SearchMetrics.revealSplit) / (1 - SearchMetrics.revealSplit);
        expect(
          width(),
          closeTo(
            SearchMetrics.cancelSize *
                (SearchMetrics.revealScale +
                    (1 - SearchMetrics.revealScale) * grow),
            0.5,
          ),
          reason: 'frame $frame',
        );
        widest = math.max(widest, width());
      }
    }
    // SwiftUI's overshoots to ~50 pt before settling at 48.
    expect(widest, greaterThan(SearchMetrics.cancelSize + 1));
    await t.pumpAndSettle();
    expect(width(), moreOrLessEquals(SearchMetrics.cancelSize));
  }, variant: ios);

  test("the close button's hide is the fitted one", () {
    // Fitted to three SwiftUI recordings (iOS 26.4), rms 1.85 pt.
    final spring = SearchMetrics.hide;
    // swiftUISpring(response: 0.26, dampingFraction: 0.56), unit mass.
    expect(spring.stiffness, closeTo(math.pow(2 * math.pi / 0.26, 2), 1e-6));
    expect(spring.damping, closeTo(4 * math.pi * 0.56 / 0.26, 1e-6));
    expect(SearchMetrics.hideFade, 0.12);
  });

  testWidgets('dismissing: the row jumps to the idle insets, the button '
      'fades and the field springs over its room, past it and back', (t) async {
    shaderEnv();
    final controller = GlassSearchController();
    addTearDown(controller.dispose);
    await t.pumpWidget(_app(controller: controller));
    controller.activate();
    await t.pumpAndSettle();
    final field = find.byType(GlassSearchField);
    final screen = t.getSize(find.byType(Scaffold)).width;
    final activeWidth = t.getSize(field).width;
    expect(t.getTopLeft(field).dx, moreOrLessEquals(SearchMetrics.inset));

    controller.cancel();
    await t.pump();
    // First frame: the whole row at the idle insets, the button still in
    // its room, so the field narrows by the inset change.
    expect(t.getTopLeft(field).dx, moreOrLessEquals(SearchMetrics.idleInset));
    const room = SearchMetrics.cancelGap + SearchMetrics.cancelSize;
    expect(
      t.getSize(field).width,
      moreOrLessEquals(screen - 2 * SearchMetrics.idleInset - room),
    );
    expect(activeWidth, greaterThan(t.getSize(field).width));

    final simulation = SpringSimulation(SearchMetrics.hide, 0, 1, 0);
    var elapsed = Duration.zero;
    var widest = 0.0;
    for (var frame = 1; frame <= 40; frame++) {
      await t.pump(const Duration(milliseconds: 16));
      elapsed += const Duration(milliseconds: 16);
      final s = elapsed.inMicroseconds / 1e6;
      if (simulation.isDone(s)) break;
      final p = simulation.x(s);
      final end = t.getTopRight(field).dx;
      expect(
        end,
        closeTo(screen - SearchMetrics.idleInset - room * (1 - p), 0.5),
        reason: 'frame $frame',
      );
      widest = math.max(widest, end);
      final button = find.byType(SearchCancelButton);
      if (button.evaluate().isNotEmpty) {
        final opacity = t
            .widget<Opacity>(
              find.ancestor(of: button, matching: find.byType(Opacity)).first,
            )
            .opacity;
        expect(
          opacity,
          closeTo((1 - p / SearchMetrics.hideFade).clamp(0.0, 1.0), 0.01),
          reason: 'frame $frame',
        );
      }
    }
    // SwiftUI's field overshoots its idle end by ~7 pt.
    expect(widest, greaterThan(screen - SearchMetrics.idleInset + 5));
    await t.pumpAndSettle();
    expect(find.byType(SearchCancelButton), findsNothing);
    expect(
      t.getTopRight(field).dx,
      moreOrLessEquals(screen - SearchMetrics.idleInset),
    );
  }, variant: ios);

  testWidgets('the close button is not clipped to a box, so its shadow '
      'keeps its round edge', (t) async {
    shaderEnv();
    for (final direction in TextDirection.values) {
      final controller = GlassSearchController();
      addTearDown(controller.dispose);
      await t.pumpWidget(_app(controller: controller, direction: direction));
      controller.activate();
      await t.pumpAndSettle();
      final button = find.byType(SearchCancelButton);
      expect(
        find.ancestor(of: button, matching: find.byType(ClipRect)),
        findsNothing,
        reason: '$direction, shown',
      );

      // While hiding, only the room's end edge cuts it.
      controller.cancel();
      await t.pump();
      final clip = find.ancestor(of: button, matching: find.byType(ClipRect));
      final size = t.getSize(clip);
      final rect = t.widget<ClipRect>(clip).clipper!.getClip(size);
      expect(rect.top, lessThan(-50), reason: '$direction');
      expect(rect.bottom, greaterThan(size.height + 50), reason: '$direction');
      if (direction == TextDirection.ltr) {
        expect(rect.left, lessThan(-50));
        expect(rect.right, moreOrLessEquals(size.width));
      } else {
        expect(rect.left, moreOrLessEquals(0));
        expect(rect.right, greaterThan(size.width + 50));
      }
      await t.pumpAndSettle();
    }
  }, variant: ios);

  testWidgets('re-activating mid-hide reveals the button again', (t) async {
    shaderEnv();
    final controller = GlassSearchController();
    addTearDown(controller.dispose);
    await t.pumpWidget(_app(controller: controller));
    controller.activate();
    await t.pumpAndSettle();
    controller.cancel();
    await t.pump(const Duration(milliseconds: 50));
    controller.activate();
    await t.pumpAndSettle();
    expect(find.byType(SearchCancelButton), findsOneWidget);
    expect(
      t.getSize(find.byType(SearchCancelButton)).width,
      moreOrLessEquals(SearchMetrics.cancelSize),
    );
    expect(
      t.getTopLeft(find.byType(GlassSearchField)).dx,
      moreOrLessEquals(SearchMetrics.inset),
    );
  }, variant: ios);

  testWidgets('navigation bar placement: the field clears the status bar', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      _app(placement: GlassSearchablePlacement.navigationBar, topPadding: 59),
    );
    expect(
      t.getTopLeft(find.byType(CupertinoTextField)).dy,
      greaterThanOrEqualTo(59),
    );
  }, variant: ios);

  testWidgets('navigation bar placement: SwiftUI drawer layout (measured)', (
    t,
  ) async {
    shaderEnv();
    t.view.physicalSize = const Size(402, 874);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final controller = GlassSearchController();
    addTearDown(controller.dispose);
    const content = Key('content');
    Future<void> pump({required bool scopes}) => t.pumpWidget(
      _app(
        controller: controller,
        placement: GlassSearchablePlacement.navigationBar,
        topPadding: 62,
        scopes: scopes ? const ['All', 'Mail', 'Notes'] : null,
        child: const SizedBox.expand(key: content),
      ),
    );
    await pump(scopes: false);
    controller.activate();
    await t.pumpAndSettle();
    // -controls searchdrawerquery: field 16..331 x 70..114, close 342..386.
    final field = t.getRect(find.byType(GlassSearchField));
    expect(field, rectMoreOrLessEquals(const Rect.fromLTRB(16, 70, 331, 114)));
    final close = t.getRect(find.byType(SearchCancelButton));
    expect(close, rectMoreOrLessEquals(const Rect.fromLTRB(342, 70, 386, 114)));
    expect(t.getTopLeft(find.byKey(content)).dy, moreOrLessEquals(122));
    // With scopes: the bar 10 under the field, the content 10 under it.
    await pump(scopes: true);
    await t.pumpAndSettle();
    final bar = t.getRect(
      find.byWidgetPredicate((w) => w is GlassSegmentedControl),
    );
    expect(bar.top, moreOrLessEquals(124));
    expect(bar.left, moreOrLessEquals(16));
    expect(bar.right, moreOrLessEquals(386));
    expect(t.getTopLeft(find.byKey(content)).dy, moreOrLessEquals(166));
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

  testWidgets('scopes show at the top once a query is typed, as SwiftUI', (
    t,
  ) async {
    shaderEnv();
    final controller = GlassSearchController();
    addTearDown(controller.dispose);
    var scope = -1;
    await t.pumpWidget(
      _app(
        controller: controller,
        scopes: const ['All', 'Mine'],
        onScopeChanged: (i) => scope = i,
        topPadding: 62,
      ),
    );
    expect(find.byType(GlassSegmentedControl<int>), findsNothing);
    await t.tap(find.byType(CupertinoTextField));
    await t.pumpAndSettle();
    // Active but empty: no scopes yet (measured, -controls searchscopes).
    expect(find.byType(GlassSegmentedControl<int>), findsNothing);
    await t.enterText(find.byType(CupertinoTextField), 'Ro');
    await t.pumpAndSettle();
    final bar = t.getRect(find.byType(GlassSegmentedControl<int>));
    // -controls searchscopesquery: 16 pt in, 2 pt under the safe area.
    expect(bar.left, SearchMetrics.scopeInset);
    expect(bar.right, 800 - SearchMetrics.scopeInset);
    expect(bar.top, 62 + SearchMetrics.scopeTop);
    await t.tap(find.text('Mine'));
    await t.pumpAndSettle();
    expect(scope, 1);
    expect(controller.scopeIndex, 1);
  }, variant: ios);

  testWidgets('suggestions are a plain list under the status bar', (t) async {
    shaderEnv();
    await t.pumpWidget(
      _app(
        topPadding: 62,
        suggestions: (context, search) => const [
          GlassSearchSuggestion(title: Text('Apple')),
          GlassSearchSuggestion(title: Text('Banana')),
        ],
      ),
    );
    await t.tap(find.byType(CupertinoTextField));
    await t.pumpAndSettle();
    final rows = find.byType(GlassSearchSuggestionRow);
    final first = t.getRect(rows.first);
    final second = t.getRect(rows.at(1));
    // -controls searchactive: separator at 62, rows 53.67 apart.
    expect(first.top, 62 + 1);
    expect(second.top - first.top, closeTo(53.67, 0.01));
    expect(first.left, 0);
    final title = t.widget<DefaultTextStyle>(
      find
          .ancestor(
            of: find.text('Apple'),
            matching: find.byType(DefaultTextStyle),
          )
          .first,
    );
    expect(
      title.style.color?.toARGB32(),
      GlassColors.systemBlue.color.toARGB32(),
    );
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
      SearchMetrics.cancelSize,
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
      matchesSemantics(
        isButton: true,
        label: 'Cancel',
        hasTapAction: true,
        isFocusable: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );
    expect(
      t.getSemantics(find.byType(GlassSearchSuggestionRow).first),
      matchesSemantics(isButton: true, hasTapAction: true),
    );
    semantics.dispose();
  }, variant: ios);

  testWidgets('Material: a search anchor, scopes hidden until active', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(_app(scopes: const ['All', 'Mine']));
    // SearchAnchor.bar builds a private SearchAnchor subclass.
    expect(find.bySubtype<SearchAnchor>(), findsOneWidget);
    expect(find.byType(SegmentedButton<int>), findsNothing);
  }, variant: android);

  testWidgets('Material: scopes show only while search is active', (t) async {
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
    expect(controller.isActive, false);
    expect(find.byType(SegmentedButton<int>), findsNothing);
    await t.tap(find.byType(SearchBar));
    await t.pumpAndSettle();
    expect(controller.isActive, true);
    expect(find.byType(SegmentedButton<int>), findsOneWidget);
    await t.tap(find.text('Mine'));
    await t.pumpAndSettle();
    expect(scope, 1);
    expect(controller.scopeIndex, 1);
    // Closing the view with an empty field ends search.
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(controller.isActive, false);
    expect(find.byType(SegmentedButton<int>), findsNothing);
  }, variant: android);

  testWidgets('Material: a query keeps scopes under the bar until cancel', (
    t,
  ) async {
    shaderEnv();
    final controller = GlassSearchController();
    addTearDown(controller.dispose);
    await t.pumpWidget(
      _app(controller: controller, scopes: const ['All', 'Mine']),
    );
    await t.tap(find.byType(SearchBar));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, 'glass');
    await t.pump();
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(controller.text, 'glass');
    expect(controller.isActive, true);
    expect(find.byType(SegmentedButton<int>), findsOneWidget);
    controller.cancel();
    await t.pumpAndSettle();
    expect(find.byType(SegmentedButton<int>), findsNothing);
  }, variant: android);

  testWidgets('Material: cancelling from outside closes the open view', (
    t,
  ) async {
    shaderEnv();
    final controller = GlassSearchController();
    addTearDown(controller.dispose);
    await t.pumpWidget(
      _app(controller: controller, scopes: const ['All', 'Mine']),
    );
    await t.tap(find.byType(SearchBar));
    await t.pumpAndSettle();
    expect(find.byType(SegmentedButton<int>), findsOneWidget);
    controller.cancel();
    await t.pumpAndSettle();
    expect(controller.textController.isOpen, false);
    expect(controller.isActive, false);
    expect(find.byType(SegmentedButton<int>), findsNothing);
  }, variant: android);
}

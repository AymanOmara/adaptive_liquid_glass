import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/zoom_transition/zoom_transition_metrics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart' show SemanticsAction, SemanticsNode;
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

const _sourceRect = Rect.fromLTWH(40, 200, 160, 200);
const _page = ValueKey('zoom-page');
const _card = ValueKey('card');

/// A home page with a card source at [_sourceRect] (or the end side in
/// RTL), a second same-id source in namespace 'other', and a button
/// pushing a zoom route from the card.
Widget _app({
  Object? namespace,
  bool showSource = true,
  bool disableAnimations = false,
  bool dragToDismiss = true,
  TextDirection direction = TextDirection.ltr,
  GlassRenderMode? mode,
  bool canPop = true,
  Widget Function(BuildContext)? body,
}) => CupertinoApp(
  builder: (context, child) => Directionality(
    textDirection: direction,
    child: MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: disableAnimations),
      child: child!,
    ),
  ),
  onGenerateRoute: (settings) => switch (settings.name) {
    '/' => CupertinoPageRoute<void>(builder: (c) => _Home(showSource)),
    _ => GlassZoomPageRoute<String>(
      sourceId: 'card',
      namespace: namespace,
      dragToDismiss: dragToDismiss,
      mode: mode,
      settings: settings,
      builder: (c) => PopScope(
        canPop: canPop,
        child:
            body?.call(c) ??
            const SizedBox.expand(key: _page, child: Text('Detail')),
      ),
    ),
  },
);

class _Home extends StatelessWidget {
  const _Home(this.showSource);
  final bool showSource;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (showSource)
        Positioned.fromRect(
          rect: _sourceRect,
          child: const GlassZoomSource(
            id: 'card',
            borderRadius: BorderRadius.all(Radius.circular(24)),
            child: ColoredBox(key: _card, color: Color(0xFF0000FF)),
          ),
        ),
      // Same id in another namespace, elsewhere.
      Positioned.fromRect(
        rect: const Rect.fromLTWH(500, 300, 100, 100),
        child: const GlassZoomSource(
          id: 'card',
          namespace: 'other',
          child: ColoredBox(color: Color(0xFF00FF00)),
        ),
      ),
      Positioned(
        left: 0,
        bottom: 0,
        child: CupertinoButton(
          onPressed: () => Navigator.pushNamed(context, '/detail'),
          child: const Text('Open'),
        ),
      ),
    ],
  );
}

/// The flying page's on-screen rect.
Rect _flight(WidgetTester t) => t.getRect(find.byKey(_page));

/// Whether the home card paints (the source hides while pushed).
double _sourceOpacity(WidgetTester t) => t
    .widget<Opacity>(
      find
          .ancestor(of: find.byKey(_card), matching: find.byType(Opacity))
          .first,
    )
    .opacity;

Future<void> _open(WidgetTester t) async {
  await t.tap(find.text('Open'));
  // The pushed route's first frame is offstage (heroes measure it).
  await t.pump();
  await t.pump();
}

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));

  testWidgets('grows from the source frame to the screen and back', (t) async {
    await t.pumpWidget(_app());
    await _open(t);
    // First frame: the page is aspect-filled into the source's frame.
    final start = _flight(t);
    expect(start.center.dx, closeTo(_sourceRect.center.dx, 1));
    expect(start.center.dy, closeTo(_sourceRect.center.dy, 1));
    expect(
      start.width >= _sourceRect.width - 1 ||
          start.height >= _sourceRect.height - 1,
      isTrue,
    );
    expect(_sourceOpacity(t), 0);
    await t.pump(ZoomTransitionMetrics.duration ~/ 2);
    final mid = _flight(t);
    expect(mid.width, greaterThan(start.width));
    await t.pumpAndSettle();
    expect(_flight(t), const Rect.fromLTWH(0, 0, 800, 600));
    expect(find.text('Detail'), findsOneWidget);

    t.state<NavigatorState>(find.byType(Navigator)).pop('x');
    await t.pump();
    await t.pump(ZoomTransitionMetrics.reverseDuration ~/ 2);
    expect(_flight(t).width, lessThan(800));
    await t.pumpAndSettle();
    expect(find.text('Detail'), findsNothing);
    expect(_sourceOpacity(t), 1);
  }, variant: ios);

  testWidgets('the source is clipped with its corner radius at the start', (
    t,
  ) async {
    await t.pumpWidget(_app());
    await _open(t);
    final clip = t.widget<ClipRRect>(
      find
          .ancestor(of: find.byKey(_page), matching: find.byType(ClipRRect))
          .first,
    );
    expect((clip.borderRadius as BorderRadius).topLeft.x, closeTo(24, 0.5));
  }, variant: ios);

  testWidgets('namespace picks the matching source', (t) async {
    await t.pumpWidget(_app(namespace: 'other'));
    await _open(t);
    expect(_flight(t).center, const Offset(550, 350));
  }, variant: ios);

  testWidgets('missing source: zooms from the centre', (t) async {
    await t.pumpWidget(_app(showSource: false));
    await _open(t);
    final start = _flight(t);
    expect(start.center, const Offset(400, 300));
    expect(start.width, lessThan(800));
    await t.pumpAndSettle();
    expect(_flight(t), const Rect.fromLTWH(0, 0, 800, 600));
  }, variant: ios);

  testWidgets('Reduce Motion cross-fades at full size', (t) async {
    await t.pumpWidget(_app(disableAnimations: true));
    await _open(t);
    expect(_flight(t), const Rect.fromLTWH(0, 0, 800, 600));
    expect(
      find.ancestor(
        of: find.byKey(_page),
        matching: find.byType(FadeTransition),
      ),
      findsWidgets,
    );
    await t.pumpAndSettle();
  }, variant: ios);

  group('drag to dismiss', () {
    testWidgets('a long downward drag zooms back into the source', (t) async {
      await t.pumpWidget(_app());
      await _open(t);
      await t.pumpAndSettle();
      final g = await t.startGesture(const Offset(400, 200));
      await g.moveBy(const Offset(0, 20));
      await g.moveBy(const Offset(0, 100));
      await t.pump();
      final dragged = _flight(t);
      expect(dragged.width, lessThan(800));
      expect(dragged.center.dy, greaterThan(300));
      await g.moveBy(const Offset(0, 100));
      await g.up();
      await t.pumpAndSettle();
      expect(find.text('Detail'), findsNothing);
      expect(_sourceOpacity(t), 1);
    }, variant: ios);

    testWidgets('a short drag springs back', (t) async {
      await t.pumpWidget(_app());
      await _open(t);
      await t.pumpAndSettle();
      final g = await t.startGesture(const Offset(400, 200));
      await g.moveBy(const Offset(0, 20));
      await t.pump(const Duration(milliseconds: 500));
      await g.moveBy(const Offset(0, 10));
      await t.pump(const Duration(milliseconds: 500));
      await g.up();
      await t.pumpAndSettle();
      expect(find.text('Detail'), findsOneWidget);
      expect(_flight(t), const Rect.fromLTWH(0, 0, 800, 600));
    }, variant: ios);

    testWidgets('PopScope refusal springs back', (t) async {
      await t.pumpWidget(_app(canPop: false));
      await _open(t);
      await t.pumpAndSettle();
      await t.dragFrom(const Offset(400, 100), const Offset(0, 400));
      await t.pumpAndSettle();
      expect(find.text('Detail'), findsOneWidget);
      expect(_flight(t), const Rect.fromLTWH(0, 0, 800, 600));
    }, variant: ios);

    for (final direction in TextDirection.values) {
      testWidgets('leading-edge swipe dismisses, ${direction.name}', (t) async {
        await t.pumpWidget(_app(direction: direction));
        await _open(t);
        await t.pumpAndSettle();
        final rtl = direction == TextDirection.rtl;
        // From the trailing edge: nothing.
        await t.dragFrom(
          Offset(rtl ? 4 : 796, 300),
          Offset(rtl ? 400 : -400, 0),
        );
        await t.pumpAndSettle();
        expect(find.text('Detail'), findsOneWidget);
        // From the leading edge: dismissed.
        await t.dragFrom(
          Offset(rtl ? 796 : 4, 300),
          Offset(rtl ? -400 : 400, 0),
        );
        await t.pumpAndSettle();
        expect(find.text('Detail'), findsNothing);
      }, variant: ios);
    }

    testWidgets('dragToDismiss false ignores drags', (t) async {
      await t.pumpWidget(_app(dragToDismiss: false));
      await _open(t);
      await t.pumpAndSettle();
      await t.dragFrom(const Offset(400, 100), const Offset(0, 400));
      await t.pumpAndSettle();
      expect(find.text('Detail'), findsOneWidget);
    }, variant: ios);

    testWidgets('inner vertical scrollables keep their drags', (t) async {
      await t.pumpWidget(
        _app(
          body: (c) => ListView(
            key: _page,
            children: [for (var i = 0; i < 50; i++) Text('Row $i')],
          ),
        ),
      );
      await _open(t);
      await t.pumpAndSettle();
      await t.dragFrom(const Offset(400, 400), const Offset(0, -300));
      await t.pumpAndSettle();
      expect(find.byKey(_page), findsOneWidget);
      expect(find.text('Row 0'), findsNothing);
    }, variant: ios);

    testWidgets('assistive tech gets a dismiss action', (t) async {
      final semantics = t.ensureSemantics();
      await t.pumpWidget(_app());
      await _open(t);
      await t.pumpAndSettle();
      // The dismiss action sits on an ancestor of the page's node.
      SemanticsNode? dismissible = t.getSemantics(find.byKey(_page));
      while (dismissible != null &&
          !dismissible.getSemanticsData().hasAction(SemanticsAction.dismiss)) {
        dismissible = dismissible.parent;
      }
      expect(dismissible, isNotNull);
      final owner = dismissible!.owner!;
      owner.performAction(dismissible.id, SemanticsAction.dismiss);
      await t.pumpAndSettle();
      expect(find.text('Detail'), findsNothing);
      semantics.dispose();
    }, variant: ios);
  });

  testWidgets('Material path: container transform timing, no drag', (t) async {
    await t.pumpWidget(_app(mode: GlassRenderMode.material));
    await _open(t);
    expect(_flight(t).center.dx, closeTo(_sourceRect.center.dx, 1));
    await t.pump(ZoomTransitionMetrics.materialDuration);
    await t.pump();
    expect(_flight(t), const Rect.fromLTWH(0, 0, 800, 600));
    await t.dragFrom(const Offset(400, 100), const Offset(0, 400));
    await t.pumpAndSettle();
    expect(find.text('Detail'), findsOneWidget);
  }, variant: ios);

  test('curves track the recorded SwiftUI zoom (iOS 26.4)', () {
    // Width progress of the native page, source 160 pt → screen 402 pt,
    // from build/motion/zoom (zoommotion scene); ms since motion start.
    const push = {72: 0.38, 139: 0.66, 185: 0.78, 259: 0.92, 335: 0.96};
    const pop = {49: 0.20, 99: 0.48, 149: 0.73, 199: 0.88, 299: 0.99};
    final d = ZoomTransitionMetrics.duration.inMilliseconds;
    final r = ZoomTransitionMetrics.reverseDuration.inMilliseconds;
    push.forEach((ms, p) {
      expect(ZoomTransitionMetrics.curve.transform(ms / d), closeTo(p, 0.08));
    });
    pop.forEach((ms, p) {
      // The route animation runs 1 → 0 on pop.
      final v = ZoomTransitionMetrics.reverseCurve.transform(1 - ms / r);
      expect(1 - v, closeTo(p, 0.04));
    });
    expect(ZoomTransitionMetrics.curve.transform(1), 1);
    expect(ZoomTransitionMetrics.reverseCurve.transform(0), 0);
  });

  testWidgets('pushGlassZoom returns the popped value', (t) async {
    late BuildContext home;
    await t.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (c) {
            home = c;
            return const Center(
              child: SizedBox(
                width: 100,
                height: 100,
                child: GlassZoomSource(id: 1, child: Text('src')),
              ),
            );
          },
        ),
      ),
    );
    final result = pushGlassZoom<int>(
      home,
      sourceId: 1,
      builder: (c) => CupertinoButton(
        onPressed: () => Navigator.pop(c, 7),
        child: const Text('Back'),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Back'));
    await t.pumpAndSettle();
    expect(await result, 7);
  }, variant: ios);
}

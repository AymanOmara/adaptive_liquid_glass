import 'package:adaptive_liquid_glass/src/button/glass_button.dart';
import 'package:adaptive_liquid_glass/src/full_screen_cover/full_screen_cover_metrics.dart';
import 'package:adaptive_liquid_glass/src/full_screen_cover/glass_full_screen_cover_handle.dart';
import 'package:adaptive_liquid_glass/src/full_screen_cover/show_glass_full_screen_cover.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Dialog, IconButton, Icons, MaterialApp, TextButton;
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

/// The cover's content, with a button popping 'y'.
WidgetBuilder get _coverBody =>
    (context) => Column(
      children: [
        const Text('Cover'),
        CupertinoButton(
          onPressed: () => Navigator.pop(context, 'y'),
          child: const Text('Close'),
        ),
      ],
    );

/// A CupertinoApp with a button opening a [showGlassFullScreenCover]
/// cover, reporting its handle to [onShown].
Widget _glassApp(
  void Function(GlassFullScreenCoverHandle<String> cover)? onShown, {
  bool disableAnimations = false,
  TextDirection direction = TextDirection.ltr,
  String? semanticLabel,
  bool dragToDismiss = false,
  bool showsCloseButton = false,
  String? closeButtonSemanticLabel,
  WidgetBuilder? body,
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
  home: Builder(
    builder: (context) => Center(
      child: Column(
        children: [
          const Text('home'),
          CupertinoButton(
            onPressed: onShown == null
                ? null
                : () => onShown(
                    showGlassFullScreenCover<String>(
                      context: context,
                      builder: body ?? _coverBody,
                      semanticLabel: semanticLabel,
                      dragToDismiss: dragToDismiss,
                      showsCloseButton: showsCloseButton,
                      closeButtonSemanticLabel: closeButtonSemanticLabel,
                    ),
                  ),
            child: const Text('Open'),
          ),
        ],
      ),
    ),
  ),
);

/// A MaterialApp host for the Material path.
Widget _materialApp(
  void Function(GlassFullScreenCoverHandle<String> cover) onShown, {
  bool dragToDismiss = false,
  bool showsCloseButton = false,
  String? closeButtonSemanticLabel,
  TextDirection direction = TextDirection.ltr,
}) => MaterialApp(
  builder: (context, child) =>
      Directionality(textDirection: direction, child: child!),
  home: Builder(
    builder: (context) => Center(
      child: TextButton(
        onPressed: () => onShown(
          showGlassFullScreenCover<String>(
            context: context,
            builder: (c) => const Text('Cover'),
            dragToDismiss: dragToDismiss,
            showsCloseButton: showsCloseButton,
            closeButtonSemanticLabel: closeButtonSemanticLabel,
          ),
        ),
        child: const Text('Open'),
      ),
    ),
  ),
);

/// The cover's edge-to-edge background.
Finder get _background => find
    .ancestor(of: find.text('Cover'), matching: find.byType(ColoredBox))
    .first;

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('opens over the whole screen, opaque; the page below is off', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(_glassApp((_) {}));
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(find.text('Cover'), findsOneWidget);
    // The background fills the screen edge to edge.
    expect(
      t.getSize(_background),
      t.view.physicalSize / t.view.devicePixelRatio,
    );
    // Opaque: the page below is offstage, not gone.
    expect(find.text('home'), findsNothing);
    expect(find.text('home', skipOffstage: false), findsOneWidget);
  }, variant: ios);

  testWidgets('slides up from the bottom', (t) async {
    shaderEnv();
    await t.pumpWidget(_glassApp((_) {}));
    await t.tap(find.text('Open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    final midAnimation = t.getTopLeft(find.text('Cover')).dy;
    expect(midAnimation, greaterThan(0));
    expect(midAnimation, lessThan(600));
    await t.pumpAndSettle();
    expect(t.getTopLeft(find.text('Cover')).dy, moreOrLessEquals(0));
  }, variant: ios);

  testWidgets('Reduce Motion: cross-fades in place instead of sliding', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(_glassApp((_) {}, disableAnimations: true));
    await t.tap(find.text('Open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(t.getTopLeft(find.text('Cover')).dy, moreOrLessEquals(0));
    expect(
      find.ancestor(
        of: find.text('Cover'),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );
    final fade = find
        .ancestor(of: find.text('Cover'), matching: find.byType(FadeTransition))
        .first;
    final opacity = t.widget<FadeTransition>(fade).opacity.value;
    expect(opacity, greaterThan(0));
    expect(opacity, lessThan(1));
    await t.pumpAndSettle();
    expect(find.text('Cover'), findsOneWidget);
  }, variant: ios);

  testWidgets('the handle dismisses it with a value; twice is a no-op', (
    t,
  ) async {
    shaderEnv();
    GlassFullScreenCoverHandle<String>? cover;
    await t.pumpWidget(_glassApp((c) => cover = c));
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(cover!.isActive, isTrue);
    cover!.dismiss('x');
    await t.pumpAndSettle();
    expect(await cover!.result, 'x');
    expect(cover!.isActive, isFalse);
    expect(find.text('Cover'), findsNothing);
    cover!.dismiss('again');
    await t.pumpAndSettle();
    expect(find.text('Cover'), findsNothing);
  }, variant: ios);

  testWidgets('Navigator.pop from inside completes the result', (t) async {
    shaderEnv();
    GlassFullScreenCoverHandle<String>? cover;
    await t.pumpWidget(_glassApp((c) => cover = c));
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await t.tap(find.text('Close'));
    await t.pumpAndSettle();
    expect(await cover!.result, 'y');
    expect(cover!.isActive, isFalse);
    expect(find.text('Cover'), findsNothing);
  }, variant: ios);

  testWidgets('the background is edge to edge, the content in the safe area', (
    t,
  ) async {
    shaderEnv();
    t.view.physicalSize = const Size(402, 874);
    t.view.devicePixelRatio = 1;
    t.view.padding = const FakeViewPadding(top: 59);
    addTearDown(t.view.reset);
    await t.pumpWidget(_glassApp((_) {}));
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(t.getTopLeft(_background).dy, moreOrLessEquals(0));
    expect(t.getSize(_background), const Size(402, 874));
    expect(t.getTopLeft(find.text('Cover')).dy, greaterThanOrEqualTo(59));
  }, variant: ios);

  testWidgets('the route scopes its semantics and carries its label', (
    t,
  ) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(_glassApp((_) {}, semanticLabel: 'Player'));
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel('Player'), findsOneWidget);
    expect(
      t.getSemantics(find.bySemanticsLabel('Player')),
      matchesSemantics(scopesRoute: true, namesRoute: true, label: 'Player'),
    );
    s.dispose();
  }, variant: ios);

  testWidgets('right to left: renders and closes', (t) async {
    shaderEnv();
    GlassFullScreenCoverHandle<String>? cover;
    await t.pumpWidget(
      _glassApp((c) => cover = c, direction: TextDirection.rtl),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(find.text('Cover'), findsOneWidget);
    expect(Directionality.of(t.element(find.text('Cover'))), TextDirection.rtl);
    cover!.dismiss();
    await t.pumpAndSettle();
    expect(find.text('Cover'), findsNothing);
    expect(await cover!.result, isNull);
  }, variant: ios);

  testWidgets('Material: a full-screen dialog; the handle dismisses it', (
    t,
  ) async {
    shaderEnv();
    GlassFullScreenCoverHandle<String>? cover;
    await t.pumpWidget(_materialApp((c) => cover = c));
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Cover'), findsOneWidget);
    cover!.dismiss('done');
    await t.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(await cover!.result, 'done');
    expect(cover!.isActive, isFalse);
  }, variant: android);

  /// Drags the cover by [dy] from its middle, then releases.
  Future<void> dragCover(WidgetTester t, double dy) async {
    final g = await t.startGesture(t.getCenter(_background));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(Offset(0, dy / 10));
      await t.pump(const Duration(milliseconds: 100));
    }
    await g.up();
  }

  testWidgets('the slide follows the fitted SwiftUI timing', (t) async {
    shaderEnv();
    await t.pumpWidget(_glassApp((_) {}));
    await t.tap(find.text('Open'));
    await t.pump();
    final height = t.view.physicalSize.height / t.view.devicePixelRatio;
    await t.pump(const Duration(milliseconds: 220));
    final expected =
        height * (1 - FullScreenCoverMetrics.curve.transform(220 / 440));
    expect(
      t.getTopLeft(_background).dy,
      moreOrLessEquals(expected, epsilon: 1),
    );
    await t.pump(const Duration(milliseconds: 221));
    expect(t.getTopLeft(_background).dy, moreOrLessEquals(0));
    expect(FullScreenCoverMetrics.duration.inMilliseconds, 440);
  }, variant: ios);

  testWidgets('no drag to dismiss unless asked, as SwiftUI', (t) async {
    shaderEnv();
    await t.pumpWidget(_glassApp((_) {}));
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await t.drag(_background, const Offset(0, 500));
    await t.pumpAndSettle();
    expect(find.text('Cover'), findsOneWidget);
    expect(t.getTopLeft(_background).dy, moreOrLessEquals(0));
  }, variant: ios);

  testWidgets('dragToDismiss: past a quarter it closes with null', (t) async {
    shaderEnv();
    GlassFullScreenCoverHandle<String>? cover;
    await t.pumpWidget(_glassApp((c) => cover = c, dragToDismiss: true));
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    final height = t.getSize(_background).height;
    // Follows the finger while held.
    final g = await t.startGesture(t.getCenter(_background));
    await g.moveBy(const Offset(0, 20));
    await g.moveBy(const Offset(0, 80));
    await t.pump();
    expect(t.getTopLeft(_background).dy, greaterThanOrEqualTo(80));
    for (var i = 0; i < 5; i++) {
      await g.moveBy(Offset(0, height * 0.04));
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pump(const Duration(milliseconds: 300));
    await g.up();
    await t.pumpAndSettle();
    expect(find.text('Cover'), findsNothing);
    expect(await cover!.result, isNull);
  }, variant: ios);

  testWidgets('dragToDismiss: a short slow drag springs back', (t) async {
    shaderEnv();
    await t.pumpWidget(_glassApp((_) {}, dragToDismiss: true));
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await dragCover(t, 100);
    await t.pump(const Duration(milliseconds: 50));
    expect(t.getTopLeft(_background).dy, greaterThan(1));
    await t.pumpAndSettle();
    expect(find.text('Cover'), findsOneWidget);
    expect(t.getTopLeft(_background).dy, moreOrLessEquals(0));
  }, variant: ios);

  testWidgets('dragToDismiss: a fast fling closes it', (t) async {
    shaderEnv();
    await t.pumpWidget(_glassApp((_) {}, dragToDismiss: true));
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await t.fling(
      _background,
      const Offset(0, 80),
      FullScreenCoverMetrics.flingVelocity * 2,
    );
    await t.pumpAndSettle();
    expect(find.text('Cover'), findsNothing);
  }, variant: ios);

  testWidgets('dragToDismiss: upward drags resist', (t) async {
    shaderEnv();
    await t.pumpWidget(_glassApp((_) {}, dragToDismiss: true));
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    final g = await t.startGesture(t.getCenter(_background));
    await g.moveBy(const Offset(0, -20));
    await g.moveBy(const Offset(0, -100));
    await t.pump();
    // Up by under a third of the 120 dragged.
    expect(t.getTopLeft(_background).dy, lessThan(-10));
    expect(
      t.getTopLeft(_background).dy,
      greaterThanOrEqualTo(-120 * FullScreenCoverMetrics.upwardResistance),
    );
    await g.up();
    await t.pumpAndSettle();
    expect(t.getTopLeft(_background).dy, moreOrLessEquals(0));
  }, variant: ios);

  testWidgets('dragToDismiss: a PopScope can refuse; it springs back', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      _glassApp(
        (_) {},
        dragToDismiss: true,
        body: (c) => const PopScope(canPop: false, child: Text('Cover')),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await t.fling(_background, const Offset(0, 300), 3000);
    await t.pumpAndSettle();
    expect(find.text('Cover'), findsOneWidget);
    expect(t.getTopLeft(_background).dy, moreOrLessEquals(0));
  }, variant: ios);

  testWidgets('dragToDismiss, Reduce Motion: a short drag snaps back', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      _glassApp((_) {}, dragToDismiss: true, disableAnimations: true),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await dragCover(t, 100);
    await t.pump();
    expect(t.getTopLeft(_background).dy, moreOrLessEquals(0));
  }, variant: ios);

  testWidgets('dragToDismiss: assistive tech gets a dismiss action', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(
      _glassApp((_) {}, dragToDismiss: true, semanticLabel: 'Player'),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    final node = t.getSemantics(find.bySemanticsLabel('Player'));
    var target = node;
    while (!target.getSemanticsData().hasAction(SemanticsAction.dismiss)) {
      target = target.parent!;
    }
    target.owner!.performAction(target.id, SemanticsAction.dismiss);
    await t.pumpAndSettle();
    expect(find.text('Cover'), findsNothing);
    s.dispose();
  }, variant: ios);

  testWidgets('showsCloseButton: a glass xmark circle top-trailing closes it', (
    t,
  ) async {
    shaderEnv();
    t.view.physicalSize = const Size(402, 874);
    t.view.devicePixelRatio = 1;
    t.view.padding = const FakeViewPadding(top: 59);
    addTearDown(t.view.reset);
    GlassFullScreenCoverHandle<String>? cover;
    await t.pumpWidget(
      _glassApp(
        (c) => cover = c,
        showsCloseButton: true,
        body: (c) => const Text('Cover'),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    final button = find.byType(GlassButton);
    expect(button, findsOneWidget);
    expect(find.byIcon(CupertinoIcons.xmark), findsOneWidget);
    expect(t.getTopRight(button).dx, moreOrLessEquals(402 - 16));
    expect(t.getTopRight(button).dy, moreOrLessEquals(59));
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    await t.tap(button);
    await t.pumpAndSettle();
    expect(find.text('Cover'), findsNothing);
    expect(await cover!.result, isNull);
  }, variant: ios);

  testWidgets('showsCloseButton, right to left: top-left; label overridable', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      _glassApp(
        (_) {},
        showsCloseButton: true,
        closeButtonSemanticLabel: 'Fermer',
        direction: TextDirection.rtl,
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(
      t.getTopLeft(find.byType(GlassButton)).dx,
      moreOrLessEquals(FullScreenCoverMetrics.closeButtonInset),
    );
    expect(find.bySemanticsLabel('Fermer'), findsOneWidget);
  }, variant: ios);

  testWidgets('Material: close icon top-start; drag closes it', (t) async {
    shaderEnv();
    GlassFullScreenCoverHandle<String>? cover;
    await t.pumpWidget(
      _materialApp(
        (c) => cover = c,
        dragToDismiss: true,
        showsCloseButton: true,
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    final close = find.widgetWithIcon(IconButton, Icons.close);
    expect(close, findsOneWidget);
    expect(t.getTopLeft(close).dx, lessThan(20));
    expect(find.byType(GlassButton), findsNothing);
    await t.tap(close);
    await t.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(await cover!.result, isNull);
    // Again, closed by a fling down.
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await t.fling(find.byType(Dialog), const Offset(0, 200), 3000);
    await t.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  }, variant: android);

  testWidgets('Material, right to left: the close icon sits top-right', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      _materialApp(
        (_) {},
        showsCloseButton: true,
        direction: TextDirection.rtl,
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    final close = find.widgetWithIcon(IconButton, Icons.close);
    expect(t.getTopRight(close).dx, greaterThan(780));
  }, variant: android);

  testWidgets('the slide down follows the fitted SwiftUI timing', (t) async {
    shaderEnv();
    GlassFullScreenCoverHandle<String>? cover;
    await t.pumpWidget(_glassApp((c) => cover = c));
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    final height = t.view.physicalSize.height / t.view.devicePixelRatio;
    cover!.dismiss();
    await t.pump();
    await t.pump(const Duration(milliseconds: 203));
    // The reverse curve traced forward: the share of the way down.
    final expected =
        height *
        (1 - FullScreenCoverMetrics.reverseCurve.transform(1 - 203 / 406));
    expect(
      t.getTopLeft(_background).dy,
      moreOrLessEquals(expected, epsilon: 1),
    );
    expect(FullScreenCoverMetrics.reverseDuration.inMilliseconds, 406);
    await t.pump(const Duration(milliseconds: 204));
    expect(find.text('Cover'), findsNothing);
  }, variant: ios);

  testWidgets('showsCloseButton: a PopScope can refuse the close button', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      _glassApp(
        (_) {},
        showsCloseButton: true,
        body: (c) => const PopScope(canPop: false, child: Text('Cover')),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await t.tap(find.byType(GlassButton));
    await t.pumpAndSettle();
    expect(find.text('Cover'), findsOneWidget);
  }, variant: ios);

  testWidgets('Material: no drag to dismiss unless asked', (t) async {
    shaderEnv();
    await t.pumpWidget(_materialApp((_) {}));
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await t.fling(find.byType(Dialog), const Offset(0, 300), 3000);
    await t.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  }, variant: android);

  testWidgets('Material: the close icon carries the localized Close tooltip', (
    t,
  ) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(_materialApp((_) {}, showsCloseButton: true));
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(
      t.getSemantics(find.byType(IconButton)),
      matchesSemantics(
        tooltip: 'Close',
        isButton: true,
        hasTapAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    s.dispose();
  }, variant: android);

  testWidgets('Material: closeButtonSemanticLabel overrides the label', (
    t,
  ) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(
      _materialApp(
        (_) {},
        showsCloseButton: true,
        closeButtonSemanticLabel: 'Fermer',
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(find.byTooltip('Fermer'), findsOneWidget);
    s.dispose();
  }, variant: android);
}

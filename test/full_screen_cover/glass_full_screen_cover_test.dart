import 'package:adaptive_liquid_glass/src/full_screen_cover/glass_full_screen_cover_handle.dart';
import 'package:adaptive_liquid_glass/src/full_screen_cover/show_glass_full_screen_cover.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Dialog, MaterialApp, TextButton;
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
                      builder: _coverBody,
                      semanticLabel: semanticLabel,
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
  void Function(GlassFullScreenCoverHandle<String> cover) onShown,
) => MaterialApp(
  home: Builder(
    builder: (context) => Center(
      child: TextButton(
        onPressed: () => onShown(
          showGlassFullScreenCover<String>(
            context: context,
            builder: (c) => const Text('Cover'),
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
}

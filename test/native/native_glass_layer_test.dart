import 'dart:async';

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/native/native_glass_layer.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/shader/render_glass_backdrop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// `pumpWidget` provides no MediaQuery under a Directionality-only host.
Widget host(Widget child) => MediaQuery(
  data: MediaQueryData.fromView(
    WidgetsBinding.instance.platformDispatcher.implicitView!,
  ),
  child: Directionality(textDirection: TextDirection.ltr, child: child),
);

/// iOS 26 picks native glass by default; `native: false` opts out to the
/// shader through the theme.
Widget themed(Widget child, {bool native = true}) => host(
  native
      ? child
      : LiquidGlassTheme(
          data: const LiquidGlassThemeData(defaultMode: GlassRenderMode.shader),
          child: child,
        ),
);

void iosEnv() {
  GlassPlatform.instance.debugEnvironment = const GlassEnvironment(
    platform: TargetPlatform.iOS,
    iosMajorVersion: 26,
    reduceTransparency: false,
    shaderSupported: true,
  );
}

/// Mocks platform view creation and records `setShapes` payloads sent to
/// the created view's channel. View ids keep counting across tests, so the
/// channel is mocked for the id in each `create` call. [create] delays the
/// `create` reply.
List<Map<Object?, Object?>> mockNative(
  WidgetTester t, {
  Future<void> Function()? create,
}) {
  final messenger = t.binding.defaultBinaryMessenger;
  final sent = <Map<Object?, Object?>>[];
  final channels = <MethodChannel>[];
  messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
    call,
  ) async {
    if (call.method != 'create') return null;
    final id = (call.arguments as Map<Object?, Object?>)['id']! as int;
    final channel = MethodChannel('adaptive_liquid_glass/native_glass_$id');
    channels.add(channel);
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'setShapes') {
        sent.add(call.arguments as Map<Object?, Object?>);
      }
      return null;
    });
    await create?.call();
    return id;
  });
  addTearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final c in channels) {
      messenger.setMockMethodCallHandler(c, null);
    }
  });
  return sent;
}

void main() {
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('native mode sends view-local shapes', (t) async {
    iosEnv();
    final sent = mockNative(t);

    await t.pumpWidget(
      themed(
        Align(
          alignment: AlignmentDirectional.topStart,
          child: GlassGroup(
            spacing: 12,
            child: LiquidGlass(
              glass: Glass.clear.tint(const Color(0xFF336699)),
              shape: const GlassShape.rect(16),
              child: const SizedBox(width: 100, height: 40),
            ),
          ),
        ),
      ),
    );
    await t.pump();

    expect(find.byType(NativeGlassLayer), findsOneWidget);
    expect(find.byType(UiKitView), findsOneWidget);
    final last = sent.last;
    expect(last['spacing'], 12.0);
    final shape = (last['shapes']! as List).single as Map<Object?, Object?>;
    expect(shape['x'], kNativeOverhang);
    expect(shape['y'], kNativeOverhang);
    expect(shape['w'], 100.0);
    expect(shape['h'], 40.0);
    expect(shape['radius'], 16.0);
    expect(shape['capsule'], false);
    expect(shape['variant'], 1);
    expect(shape['tint'], 0xFF336699);
    expect(shape['interactive'], false);
  }, variant: ios);

  testWidgets('iOS 26: native from the first frame, no theme or flag', (
    t,
  ) async {
    iosEnv();
    mockNative(t);
    await t.pumpWidget(
      host(const LiquidGlass(child: SizedBox(width: 100, height: 40))),
    );
    // One frame: already native, never the shader backdrop.
    expect(find.byType(NativeGlassLayer), findsOneWidget);
    expect(find.byType(GlassBackdrop), findsNothing);
  }, variant: ios);

  testWidgets('explicit shader mode opts out of native on iOS 26', (t) async {
    iosEnv();
    mockNative(t);
    await t.pumpWidget(
      host(
        const LiquidGlass(
          mode: GlassRenderMode.shader,
          child: SizedBox(width: 100, height: 40),
        ),
      ),
    );
    expect(find.byType(NativeGlassLayer), findsNothing);
    expect(find.byType(GlassBackdrop), findsOneWidget);
  }, variant: ios);

  testWidgets('native payload carries the platform brightness', (t) async {
    iosEnv();
    final sent = mockNative(t);
    Widget app(Brightness b) => themed(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(platformBrightness: b),
          child: const Align(
            alignment: AlignmentDirectional.topStart,
            child: GlassGroup(
              child: LiquidGlass(child: SizedBox(width: 100, height: 40)),
            ),
          ),
        ),
      ),
    );
    await t.pumpWidget(app(Brightness.dark));
    await t.pump();
    expect(sent.last['dark'], true);
    await t.pumpWidget(app(Brightness.light));
    await t.pump();
    expect(sent.last['dark'], false);
  }, variant: ios);

  testWidgets('members sharing a unionId get one union index', (t) async {
    iosEnv();
    final sent = mockNative(t);
    await t.pumpWidget(
      themed(
        const Align(
          alignment: AlignmentDirectional.topStart,
          child: GlassGroup(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LiquidGlass(
                  unionId: 'a',
                  child: SizedBox(width: 40, height: 40),
                ),
                SizedBox(width: 20),
                LiquidGlass(child: SizedBox(width: 40, height: 40)),
                SizedBox(width: 20),
                LiquidGlass(
                  unionId: 'a',
                  child: SizedBox(width: 40, height: 40),
                ),
                LiquidGlass(unionId: 7, child: SizedBox(width: 40, height: 40)),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pump();
    final unions = [
      for (final s in sent.last['shapes']! as List)
        (s as Map<Object?, Object?>)['union'],
    ];
    expect(unions, [0, null, 0, 1]);
  }, variant: ios);

  testWidgets('each member keeps a stable id when others go away', (t) async {
    iosEnv();
    final sent = mockNative(t);
    Widget row(List<String> keys) => themed(
      Align(
        alignment: AlignmentDirectional.topStart,
        child: GlassGroup(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final k in keys)
                LiquidGlass(
                  key: ValueKey(k),
                  child: const SizedBox(width: 40, height: 40),
                ),
            ],
          ),
        ),
      ),
    );
    List<Object?> ids() => [
      for (final s in sent.last['shapes']! as List)
        (s as Map<Object?, Object?>)['id'],
    ];

    await t.pumpWidget(row(['a', 'b', 'c']));
    await t.pump();
    final first = ids();
    expect(first.toSet(), hasLength(3));
    expect(first, everyElement(isA<int>()));

    await t.pumpWidget(row(['b', 'c']));
    await t.pump();
    expect(ids(), [first[1], first[2]]);
  }, variant: ios);

  testWidgets('circles are sent with circular corners', (t) async {
    iosEnv();
    final sent = mockNative(t);
    await t.pumpWidget(
      themed(
        const Align(
          alignment: AlignmentDirectional.topStart,
          child: GlassGroup(
            child: LiquidGlass(
              shape: GlassShape.circle(),
              child: SizedBox(width: 60, height: 60),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    final shape =
        (sent.last['shapes']! as List).single as Map<Object?, Object?>;
    expect(shape['capsule'], true);
  }, variant: ios);

  testWidgets('native mode passes tight constraints through like shader', (
    t,
  ) async {
    iosEnv();
    mockNative(t);
    Future<Size> columnSize({required bool native}) async {
      await t.pumpWidget(
        themed(
          native: native,
          const Center(
            child: SizedBox(
              width: 300,
              height: 200,
              child: GlassGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LiquidGlass(child: SizedBox(width: 50, height: 50)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await t.pump();
      expect(
        find.byType(NativeGlassLayer),
        native ? findsOneWidget : findsNothing,
      );
      return t.getSize(find.byType(Column));
    }

    final shader = await columnSize(native: false);
    final native = await columnSize(native: true);
    expect(shader, const Size(300, 200));
    expect(native, shader);
  }, variant: ios);

  testWidgets('taps reach widgets behind gaps between native members', (
    t,
  ) async {
    iosEnv();
    mockNative(t);
    var taps = 0;
    await t.pumpWidget(
      themed(
        Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
              ),
            ),
            const Positioned(
              left: 100,
              top: 100,
              child: GlassGroup(
                spacing: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LiquidGlass(child: SizedBox(width: 60, height: 40)),
                    SizedBox(width: 40),
                    LiquidGlass(child: SizedBox(width: 60, height: 40)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await t.pump();
    expect(find.byType(UiKitView), findsOneWidget);

    // The gap between the members: (160..200, 100..140).
    await t.tapAt(const Offset(180, 120));
    await t.pump(kDoubleTapTimeout);
    expect(taps, 1);
  }, variant: ios);

  testWidgets('unchanged geometry is sent once', (t) async {
    iosEnv();
    final sent = mockNative(t);
    await t.pumpWidget(
      themed(
        const Align(
          alignment: AlignmentDirectional.topStart,
          child: GlassGroup(
            child: LiquidGlass(child: SizedBox(width: 100, height: 40)),
          ),
        ),
      ),
    );
    await t.pump();
    final registry = t
        .widget<NativeGlassLayer>(find.byType(NativeGlassLayer))
        .registry;
    registry.markNeedsPaint();
    await t.pump();
    registry.markNeedsPaint();
    await t.pump();
    expect(sent, hasLength(1));
  }, variant: ios);

  testWidgets('lastDrawnLocal is recorded before the view exists', (t) async {
    iosEnv();
    final pending = Completer<void>();
    final sent = mockNative(t, create: () => pending.future);
    await t.pumpWidget(
      themed(
        const Align(
          alignment: AlignmentDirectional.topStart,
          child: GlassGroup(
            child: LiquidGlass(child: SizedBox(width: 100, height: 40)),
          ),
        ),
      ),
    );
    await t.pump();
    final entry = t
        .widget<NativeGlassLayer>(find.byType(NativeGlassLayer))
        .registry
        .entries
        .single;
    expect(sent, isEmpty);
    expect(entry.lastDrawnLocal, const Rect.fromLTWH(0, 0, 100, 40));
  }, variant: ios);
}

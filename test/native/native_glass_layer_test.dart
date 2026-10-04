import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/native/native_glass_layer.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
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

void main() {
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('native mode sends view-local shapes', (t) async {
    GlassPlatform.instance.debugEnvironment = const GlassEnvironment(
      platform: TargetPlatform.iOS,
      iosMajorVersion: 26,
      reduceTransparency: false,
      shaderSupported: true,
    );
    final messenger = t.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async => call.method == 'create' ? 0 : null,
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        null,
      ),
    );
    const native = MethodChannel('adaptive_liquid_glass/native_glass_0');
    final sent = <Map<Object?, Object?>>[];
    messenger.setMockMethodCallHandler(native, (call) async {
      if (call.method == 'setShapes') {
        sent.add(call.arguments as Map<Object?, Object?>);
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(native, null));

    await t.pumpWidget(
      host(
        LiquidGlassTheme(
          data: const LiquidGlassThemeData(nativeEnabled: true),
          child: Align(
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
}

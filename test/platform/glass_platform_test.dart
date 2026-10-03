import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const method = MethodChannel('adaptive_liquid_glass');
  const events = 'adaptive_liquid_glass/reduce_transparency';

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    GlassPlatform.instance.debugReset();
    messenger.setMockMethodCallHandler(method, null);
    messenger.setMockStreamHandler(const EventChannel(events), null);
  });

  test('does not touch the channel off iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var calls = 0;
    messenger.setMockMethodCallHandler(method, (_) async {
      calls++;
      return null;
    });
    GlassPlatform.instance.ensureStarted();
    await pumpEventQueue();
    expect(calls, 0);
    expect(GlassPlatform.instance.environment.value.iosMajorVersion, isNull);
  });

  test('reads version and live Reduce Transparency on iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(method, (call) async {
      expect(call.method, 'getEnvironment');
      return {'iosMajorVersion': 26, 'reduceTransparency': false};
    });
    late MockStreamHandlerEventSink sink;
    messenger.setMockStreamHandler(
      const EventChannel(events),
      MockStreamHandler.inline(onListen: (_, s) => sink = s),
    );

    GlassPlatform.instance.ensureStarted();
    await pumpEventQueue();
    final env = GlassPlatform.instance.environment;
    expect(env.value.iosMajorVersion, 26);
    expect(env.value.reduceTransparency, isFalse);

    sink.success(true);
    await pumpEventQueue();
    expect(env.value.reduceTransparency, isTrue);
  });

  test('a channel failure leaves defaults in place', () async {
    final previous = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = previous);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(method, (_) async {
      throw PlatformException(code: 'x');
    });
    GlassPlatform.instance.ensureStarted();
    await pumpEventQueue();
    expect(GlassPlatform.instance.environment.value.iosMajorVersion, isNull);
  });
}

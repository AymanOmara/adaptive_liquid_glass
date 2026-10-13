import 'dart:async';

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

const _channel = MethodChannel('adaptive_liquid_glass');

const _both = TargetPlatformVariant({
  TargetPlatform.iOS,
  TargetPlatform.android,
});

final _image = {
  'path': '/tmp/a.heic',
  'isVideo': false,
  'mimeType': 'image/heic',
  'width': 4032,
  'height': 3024,
};
final _video = {'path': '/tmp/b.mov', 'isVideo': true, 'mimeType': null};

/// Answers `pickPhotos` with [reply] and records each call.
List<MethodCall> _mock(Future<Object?> Function(MethodCall) reply) {
  final calls = <MethodCall>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) {
        calls.add(call);
        return reply(call);
      });
  return calls;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() {
    GlassPlatform.instance.debugReset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  group('pickGlassPhotos', () {
    testWidgets('sends maxSelection and filter, parses the results', (t) async {
      final calls = _mock((_) async => [_image, _video]);
      final photos = await pickGlassPhotos(
        maxSelection: 0,
        filter: GlassPhotosPickerFilter.any,
      );
      expect(calls.single.method, 'pickPhotos');
      expect(calls.single.arguments, {'maxSelection': 0, 'filter': 'any'});
      expect(photos, const [
        GlassPickedPhoto(
          path: '/tmp/a.heic',
          isVideo: false,
          mimeType: 'image/heic',
          width: 4032,
          height: 3024,
        ),
        GlassPickedPhoto(path: '/tmp/b.mov', isVideo: true),
      ]);
    }, variant: _both);

    testWidgets('defaults to one image', (t) async {
      final calls = _mock((_) async => const <Object?>[]);
      await pickGlassPhotos();
      expect(calls.single.arguments, {'maxSelection': 1, 'filter': 'images'});
    }, variant: _both);

    testWidgets('cancel (empty or null reply) is an empty list', (t) async {
      _mock((_) async => const <Object?>[]);
      expect(await pickGlassPhotos(), isEmpty);
      _mock((_) async => null);
      expect(await pickGlassPhotos(), isEmpty);
    }, variant: _both);

    testWidgets('platform errors surface as PlatformException', (t) async {
      _mock((_) async => throw PlatformException(code: 'already_active'));
      await expectLater(pickGlassPhotos(), throwsA(isA<PlatformException>()));
    }, variant: ios);

    test('unsupported off iOS and Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await expectLater(pickGlassPhotos(), throwsUnsupportedError);
    });
  });

  group('GlassPhotosPicker', () {
    testWidgets('tapping opens the picker and passes the choice', (t) async {
      shaderEnv();
      final calls = _mock((_) async => [_image]);
      List<GlassPickedPhoto>? picked;
      await t.pumpWidget(
        plainHost(
          GlassPhotosPicker(
            label: 'Select Photos',
            maxSelection: 3,
            filter: GlassPhotosPickerFilter.videos,
            onPicked: (p) => picked = p,
          ),
        ),
      );
      expect(find.text('Select Photos'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.photo_on_rectangle), findsOneWidget);
      await t.tap(find.text('Select Photos'));
      await t.pump();
      expect(calls.single.arguments, {'maxSelection': 3, 'filter': 'videos'});
      expect(picked, hasLength(1));
      expect(picked!.single.path, '/tmp/a.heic');
    }, variant: _both);

    testWidgets('cancel does not call onPicked', (t) async {
      shaderEnv();
      _mock((_) async => const <Object?>[]);
      var called = false;
      await t.pumpWidget(
        plainHost(
          GlassPhotosPicker(label: 'Pick', onPicked: (_) => called = true),
        ),
      );
      await t.tap(find.text('Pick'));
      await t.pump();
      expect(called, isFalse);
    }, variant: ios);

    testWidgets('a child replaces the default label', (t) async {
      shaderEnv();
      final calls = _mock((_) async => const <Object?>[]);
      await t.pumpWidget(
        plainHost(
          GlassPhotosPicker(onPicked: (_) {}, child: const Text('Add')),
        ),
      );
      expect(find.byIcon(CupertinoIcons.photo_on_rectangle), findsNothing);
      await t.tap(find.text('Add'));
      await t.pump();
      expect(calls, hasLength(1));
    }, variant: ios);

    testWidgets('taps while the picker is open are ignored', (t) async {
      shaderEnv();
      final reply = Completer<Object?>();
      final calls = _mock((_) => reply.future);
      await t.pumpWidget(
        plainHost(GlassPhotosPicker(label: 'Pick', onPicked: (_) {})),
      );
      await t.tap(find.text('Pick'));
      await t.pump();
      await t.tap(find.text('Pick'));
      await t.pump();
      expect(calls, hasLength(1));
      reply.complete(const <Object?>[]);
      await t.pump();
      await t.tap(find.text('Pick'));
      await t.pump();
      expect(calls, hasLength(2));
    }, variant: ios);

    testWidgets('null onPicked disables the trigger', (t) async {
      shaderEnv();
      final calls = _mock((_) async => const <Object?>[]);
      await t.pumpWidget(
        plainHost(const GlassPhotosPicker(label: 'Pick', onPicked: null)),
      );
      await t.tap(find.text('Pick'), warnIfMissed: false);
      await t.pump();
      expect(calls, isEmpty);
    }, variant: ios);

    testWidgets('errors go to onError', (t) async {
      shaderEnv();
      _mock((_) async => throw PlatformException(code: 'no_window'));
      Object? error;
      await t.pumpWidget(
        plainHost(
          GlassPhotosPicker(
            label: 'Pick',
            onPicked: (_) {},
            onError: (e) => error = e,
          ),
        ),
      );
      await t.tap(find.text('Pick'));
      await t.pump();
      expect(error, isA<PlatformException>());
    }, variant: ios);

    testWidgets('icon-only is read as a "Photos" button', (t) async {
      shaderEnv();
      final s = t.ensureSemantics();
      await t.pumpWidget(plainHost(GlassPhotosPicker(onPicked: (_) {})));
      expect(find.bySemanticsLabel('Photos'), findsOneWidget);
      s.dispose();
    }, variant: ios);
  });
}

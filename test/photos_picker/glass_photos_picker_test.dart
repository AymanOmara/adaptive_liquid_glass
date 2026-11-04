import 'dart:async';
import 'dart:ui' as ui;

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
final _video = {
  'path': '/tmp/b.mov',
  'isVideo': true,
  'mimeType': null,
  'width': 1080,
  'height': 1920,
  'durationMs': 12345.5,
};

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

Future<void> _ready(String channel, Map<String, Object?> item) {
  final done = Completer<void>();
  ui.channelBuffers.push(
    channel,
    const StandardMethodCodec().encodeMethodCall(MethodCall('itemReady', item)),
    (_) => done.complete(),
  );
  return done.future;
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
    testWidgets('ready items arrive before completion, once each', (t) async {
      final reply = Completer<Object?>();
      final calls = _mock((_) => reply.future);
      final ready = <GlassPickedPhoto>[];
      var finished = false;
      final pending = pickGlassPhotos(onItemReady: ready.add)
        ..then((_) => finished = true);
      await t.pump();
      final channel =
          (calls.single.arguments as Map)['importChannel'] as String;
      await _ready(channel, _image);
      await _ready(channel, _image);
      expect(ready.map((p) => p.path), ['/tmp/a.heic']);
      expect(finished, isFalse);
      reply.complete([_image, _video]);
      final result = await pending;
      expect(ready, result);
      expect(ready, hasLength(2));
    }, variant: _both);

    testWidgets('older plugins deliver per-item callbacks with final result', (
      t,
    ) async {
      _mock((_) async => [_image, _video]);
      final ready = <GlassPickedPhoto>[];
      final result = await pickGlassPhotos(onItemReady: ready.add);
      expect(ready, result);
    }, variant: _both);

    testWidgets('callback errors are reported without breaking the import', (
      t,
    ) async {
      final reply = Completer<Object?>();
      final calls = _mock((_) => reply.future);
      final reported = <FlutterErrorDetails>[];
      final old = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = old);
      final pending = pickGlassPhotos(
        onItemReady: (_) => throw StateError('callback'),
      );
      await t.pump();
      final channel =
          (calls.single.arguments as Map)['importChannel'] as String;
      await _ready(channel, _image);
      reply.complete([_image]);
      expect(await pending, hasLength(1));
      expect(reported, hasLength(1));
      expect(reported.single.exception, isA<StateError>());
    }, variant: _both);

    testWidgets('a later import failure preserves earlier notifications', (
      t,
    ) async {
      final reply = Completer<Object?>();
      final calls = _mock((_) => reply.future);
      final ready = <GlassPickedPhoto>[];
      final pending = pickGlassPhotos(onItemReady: ready.add);
      final failed = expectLater(pending, throwsA(isA<PlatformException>()));
      await t.pump();
      final channel =
          (calls.single.arguments as Map)['importChannel'] as String;
      await _ready(channel, _image);
      reply.completeError(PlatformException(code: 'load_failed'));
      await failed;
      expect(ready.single.path, '/tmp/a.heic');
    }, variant: _both);

    testWidgets('each request has an isolated import channel', (t) async {
      final replies = [Completer<Object?>(), Completer<Object?>()];
      var index = 0;
      final calls = _mock((_) => replies[index++].future);
      final first = <GlassPickedPhoto>[];
      final second = <GlassPickedPhoto>[];
      final a = pickGlassPhotos(onItemReady: first.add);
      final b = pickGlassPhotos(onItemReady: second.add);
      await t.pump();
      final channels = calls
          .map((c) => (c.arguments as Map)['importChannel'] as String)
          .toList();
      expect(channels[0], isNot(channels[1]));
      await _ready(channels[1], _video);
      expect(first, isEmpty);
      expect(second.single.path, '/tmp/b.mov');
      replies[0].complete([]);
      replies[1].complete([_video]);
      await Future.wait([a, b]);
      expect(second, hasLength(1));
    }, variant: _both);

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
        GlassPickedPhoto(
          path: '/tmp/b.mov',
          isVideo: true,
          width: 1080,
          height: 1920,
          duration: Duration(microseconds: 12345500),
        ),
      ]);
    }, variant: _both);

    testWidgets('defaults to one image', (t) async {
      final calls = _mock((_) async => const <Object?>[]);
      await pickGlassPhotos();
      expect(calls.single.arguments, {'maxSelection': 1, 'filter': 'images'});
    }, variant: _both);

    testWidgets('sends downscaling and format options only when set', (
      t,
    ) async {
      final calls = _mock((_) async => const <Object?>[]);
      await pickGlassPhotos(
        maxWidth: 1024,
        maxHeight: 768,
        imageQuality: 80,
        compatibleFormat: true,
      );
      expect(calls.single.arguments, {
        'maxSelection': 1,
        'filter': 'images',
        'maxWidth': 1024,
        'maxHeight': 768,
        'imageQuality': 80,
        'compatibleFormat': true,
      });
    }, variant: _both);

    test('a video without size or duration parses as unknown', () {
      final p = GlassPickedPhoto.fromMap(const {'path': '/v', 'isVideo': true});
      expect(p.width, isNull);
      expect(p.duration, isNull);
      expect(
        GlassPickedPhoto.fromMap(const {'path': '/v', 'durationMs': 1500}),
        const GlassPickedPhoto(
          path: '/v',
          isVideo: false,
          duration: Duration(milliseconds: 1500),
        ),
      );
    });

    test('conversionFailed defaults to false and is read from the map', () {
      expect(
        GlassPickedPhoto.fromMap(const {'path': '/v'}).conversionFailed,
        isFalse,
      );
      final p = GlassPickedPhoto.fromMap(const {
        'path': '/v.mov',
        'isVideo': true,
        'conversionFailed': true,
      });
      expect(p.conversionFailed, isTrue);
      expect(p, isNot(const GlassPickedPhoto(path: '/v.mov', isVideo: true)));
      expect(p.toString(), contains('conversion failed'));
    });

    testWidgets('a plain list reply has nothing dropped', (t) async {
      _mock((_) async => [_image]);
      final photos = await pickGlassPhotos();
      expect(photos, hasLength(1));
      expect(photos.droppedCount, 0);
      photos.add(photos.first); // Still a growable list, as before.
      expect(photos, hasLength(2));
    }, variant: _both);

    testWidgets('a map reply carries the items and the dropped count', (
      t,
    ) async {
      _mock(
        (_) async => {
          'items': [
            _image,
            {..._video, 'conversionFailed': true},
          ],
          'dropped': 2,
        },
      );
      final photos = await pickGlassPhotos(maxSelection: 2);
      expect(photos, hasLength(2));
      expect(photos.droppedCount, 2);
      expect(photos.first.conversionFailed, isFalse);
      expect(photos.last.conversionFailed, isTrue);
    }, variant: _both);

    testWidgets('a map reply without items is empty', (t) async {
      _mock((_) async => <String, Object?>{});
      final photos = await pickGlassPhotos();
      expect(photos, isEmpty);
      expect(photos.droppedCount, 0);
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

  group('clearGlassPickedPhotos', () {
    testWidgets('reports cleanup failure and permits retry', (t) async {
      var failed = true;
      final calls = _mock((_) async {
        if (failed) {
          throw PlatformException(
            code: 'cleanup_failed',
            message: 'Disk denied',
          );
        }
        return null;
      });
      await expectLater(
        clearGlassPickedPhotos(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'cleanup_failed',
          ),
        ),
      );
      failed = false;
      await clearGlassPickedPhotos();
      expect(calls, hasLength(2));
    }, variant: _both);

    testWidgets('asks the platform to delete the copies', (t) async {
      final calls = _mock((_) async => null);
      await clearGlassPickedPhotos();
      expect(calls.single.method, 'clearPickedPhotos');
    }, variant: _both);

    test('does nothing off iOS and Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final calls = _mock((_) async => null);
      await clearGlassPickedPhotos();
      expect(calls, isEmpty);
    });
  });

  group('GlassPhotosPicker', () {
    testWidgets('ready callback leaves the final batch callback intact', (
      t,
    ) async {
      shaderEnv();
      final reply = Completer<Object?>();
      final calls = _mock((_) => reply.future);
      final ready = <GlassPickedPhoto>[];
      GlassPickedPhotos? picked;
      await t.pumpWidget(
        plainHost(
          GlassPhotosPicker(
            label: 'Pick',
            onPicked: (photos) => picked = photos,
            onItemReady: ready.add,
          ),
        ),
      );
      await t.tap(find.text('Pick'));
      await t.pump();
      final channel =
          (calls.single.arguments as Map)['importChannel'] as String;
      await _ready(channel, _image);
      expect(picked, isNull);
      reply.complete([_image, _video]);
      await t.pump();
      expect(picked, hasLength(2));
      expect(ready, picked);
      expect(t.widget<GlassButton>(find.byType(GlassButton)).loading, isFalse);
    }, variant: _both);

    testWidgets('notifies ready items while loading and stops after disposal', (
      t,
    ) async {
      shaderEnv();
      final reply = Completer<Object?>();
      final calls = _mock((_) => reply.future);
      final ready = <GlassPickedPhoto>[];
      var picked = false;
      await t.pumpWidget(
        plainHost(
          GlassPhotosPicker(
            label: 'Pick',
            onPicked: (_) => picked = true,
            onItemReady: ready.add,
          ),
        ),
      );
      await t.tap(find.text('Pick'));
      await t.pump();
      final channel =
          (calls.single.arguments as Map)['importChannel'] as String;
      await _ready(channel, _image);
      expect(ready, hasLength(1));
      expect(picked, isFalse);
      expect(t.widget<GlassButton>(find.byType(GlassButton)).loading, isTrue);
      await t.pumpWidget(const SizedBox());
      await _ready(channel, _video);
      reply.complete([_image, _video]);
      await t.pump();
      expect(ready, hasLength(1));
      expect(picked, isFalse);
      expect(t.takeException(), isNull);
    }, variant: _both);

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

    testWidgets('onPicked receives the dropped count', (t) async {
      shaderEnv();
      _mock(
        (_) async => {
          'items': [_image],
          'dropped': 3,
        },
      );
      GlassPickedPhotos? picked;
      await t.pumpWidget(
        plainHost(
          GlassPhotosPicker(
            label: 'Select Photos',
            onPicked: (p) => picked = p,
          ),
        ),
      );
      await t.tap(find.text('Select Photos'));
      await t.pump();
      expect(picked, hasLength(1));
      expect(picked!.droppedCount, 3);
    }, variant: _both);

    testWidgets('passes the downscaling and format options', (t) async {
      shaderEnv();
      final calls = _mock((_) async => const <Object?>[]);
      await t.pumpWidget(
        plainHost(
          GlassPhotosPicker(
            label: 'Pick',
            maxWidth: 2048,
            imageQuality: 70,
            compatibleFormat: true,
            onPicked: (_) {},
          ),
        ),
      );
      await t.tap(find.text('Pick'));
      await t.pump();
      expect(calls.single.arguments, {
        'maxSelection': 1,
        'filter': 'images',
        'maxWidth': 2048,
        'imageQuality': 70,
        'compatibleFormat': true,
      });
    }, variant: ios);

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

    testWidgets(
      'shows loading until local files finish and resets after errors',
      (t) async {
        shaderEnv();
        final reply = Completer<Object?>();
        _mock((_) => reply.future);
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
        expect(t.widget<GlassButton>(find.byType(GlassButton)).loading, isTrue);
        reply.completeError(PlatformException(code: 'load_failed'));
        await t.pump();
        expect(error, isA<PlatformException>());
        expect(
          t.widget<GlassButton>(find.byType(GlassButton)).loading,
          isFalse,
        );
      },
      variant: _both,
    );

    testWidgets('does not call onError after the trigger is disposed', (
      t,
    ) async {
      shaderEnv();
      final reply = Completer<Object?>();
      _mock((_) => reply.future);
      var reported = false;
      await t.pumpWidget(
        plainHost(
          GlassPhotosPicker(
            label: 'Pick',
            onPicked: (_) {},
            onError: (_) => reported = true,
          ),
        ),
      );
      await t.tap(find.text('Pick'));
      await t.pumpWidget(const SizedBox());
      reply.completeError(PlatformException(code: 'load_failed'));
      await t.pump();
      expect(reported, isFalse);
      expect(t.takeException(), isNull);
    }, variant: _both);

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

  Future<void> push(String channel, String method, Object? args) {
    final done = Completer<void>();
    ui.channelBuffers.push(
      channel,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
      (_) => done.complete(),
    );
    return done.future;
  }

  group('progress and cancel', () {
    testWidgets('onProgress alone opens an import channel', (tester) async {
      final reply = Completer<Object?>();
      final calls = _mock((_) => reply.future);
      final seen = <GlassPhotoImportProgress>[];
      final future = pickGlassPhotos(maxSelection: 0, onProgress: seen.add);
      await tester.pump();
      final name = (calls.single.arguments as Map)['importChannel'] as String;
      await push(name, 'progress', {
        'index': 0,
        'total': 2,
        'completed': 0,
        'itemFraction': 0.5,
      });
      reply.complete({
        'items': [_image],
        'dropped': 0,
      });
      await future;
      expect(seen.first.fraction, closeTo(0.25, 1e-9));
      expect(seen.last.phase, GlassPhotoImportPhase.done);
    }, variant: _both);

    testWidgets('controller.cancel sends cancelPhotoImport with the channel', (
      tester,
    ) async {
      final reply = Completer<Object?>();
      final calls = _mock((call) async {
        if (call.method == 'cancelPhotoImport') {
          reply.complete({
            'items': [_image],
            'dropped': 0,
            'cancelled': true,
          });
          return null;
        }
        return reply.future;
      });
      final controller = GlassPhotoImportController();
      final future = pickGlassPhotos(maxSelection: 0, controller: controller);
      await tester.pump();
      expect(controller.isActive.value, isTrue);
      controller.cancel();
      controller.cancel(); // idempotent
      final photos = await future;
      final name = (calls.first.arguments as Map)['importChannel'];
      final cancels = calls
          .where((c) => c.method == 'cancelPhotoImport')
          .toList();
      expect(cancels, hasLength(1));
      expect((cancels.single.arguments as Map)['importChannel'], name);
      expect(photos.cancelled, isTrue);
      expect(photos, hasLength(1));
      expect(controller.isActive.value, isFalse);
    }, variant: _both);

    testWidgets('a platform error after cancel is swallowed', (tester) async {
      final reply = Completer<Object?>();
      final calls = _mock((call) async {
        if (call.method == 'cancelPhotoImport') {
          reply.completeError(PlatformException(code: 'load_failed'));
          return null;
        }
        return reply.future;
      });
      final controller = GlassPhotoImportController();
      final delivered = <GlassPickedPhoto>[];
      final future = pickGlassPhotos(
        maxSelection: 0,
        controller: controller,
        onItemReady: delivered.add,
      );
      await tester.pump();
      final name = (calls.first.arguments as Map)['importChannel'] as String;
      await _ready(name, {..._video, 'index': 1});
      await _ready(name, {..._image, 'index': 0});
      controller.cancel();
      final photos = await future;
      expect(photos.cancelled, isTrue);
      expect(delivered, hasLength(2));
      expect(photos.map((p) => p.path), [_image['path'], _video['path']]);
      expect(photos.map((p) => p.index), [0, 1]);
    }, variant: _both);

    testWidgets('cancel after completion is a no-op', (tester) async {
      final calls = _mock(
        (_) async => {
          'items': [_image],
          'dropped': 0,
        },
      );
      final controller = GlassPhotoImportController();
      final photos = await pickGlassPhotos(controller: controller);
      controller.cancel();
      await tester.pump();
      expect(photos.cancelled, isFalse);
      expect(calls.where((c) => c.method == 'cancelPhotoImport'), isEmpty);
    }, variant: _both);

    testWidgets('cancel before any import does nothing', (tester) async {
      final calls = _mock((_) async => const <Object?>[]);
      GlassPhotoImportController().cancel();
      await tester.pump();
      expect(calls, isEmpty);
    }, variant: _both);

    testWidgets('a controller drives one import at a time, then is reusable', (
      tester,
    ) async {
      final reply = Completer<Object?>();
      _mock((_) => reply.future);
      final controller = GlassPhotoImportController();
      final first = pickGlassPhotos(controller: controller);
      await tester.pump();
      await expectLater(
        pickGlassPhotos(controller: controller),
        throwsStateError,
      );
      reply.complete(const <Object?>[]);
      await first;
      _mock((_) async => [_image]);
      expect(await pickGlassPhotos(controller: controller), hasLength(1));
    }, variant: _both);

    testWidgets('a disposed controller: cancel is a no-op, attach throws', (
      tester,
    ) async {
      final calls = _mock((_) async => const <Object?>[]);
      final controller = GlassPhotoImportController()..dispose();
      controller.cancel();
      await expectLater(
        pickGlassPhotos(controller: controller),
        throwsStateError,
      );
      expect(calls, isEmpty);
    }, variant: _both);

    testWidgets('a bare list reply still parses, cancelled false', (
      tester,
    ) async {
      _mock((_) async => [_image, _video]);
      final photos = await pickGlassPhotos(maxSelection: 0);
      expect(photos, hasLength(2));
      expect(photos.cancelled, isFalse);
    }, variant: _both);

    testWidgets('itemReady carries index', (tester) async {
      final reply = Completer<Object?>();
      final calls = _mock((_) => reply.future);
      final got = <GlassPickedPhoto>[];
      final future = pickGlassPhotos(maxSelection: 0, onItemReady: got.add);
      await tester.pump();
      final name = (calls.single.arguments as Map)['importChannel'] as String;
      await _ready(name, {..._video, 'index': 1});
      await _ready(name, {..._image, 'index': 0});
      reply.complete({
        'items': [
          {..._image, 'index': 0},
          {..._video, 'index': 1},
        ],
      });
      final photos = await future;
      expect(got.map((p) => p.index), [1, 0]);
      expect(photos.map((p) => p.index), [0, 1]);
    }, variant: _both);
  });
}

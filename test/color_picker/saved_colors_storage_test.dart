import 'dart:async';

import 'package:adaptive_liquid_glass/src/color_picker/saved_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('adaptive_liquid_glass');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SavedColors.debugReset();
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    SavedColors.debugReset();
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'reloads a saved palette after a fresh session, including alpha',
    () async {
      Object? stored;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getSavedColors') return stored;
        stored = call.arguments;
        return null;
      });
      const colors = [Color(0x80123456), Color(0xFFFFFFFF)];
      await SavedColors.save(colors);
      SavedColors.debugReset();
      await SavedColors.ensureLoaded();
      expect(SavedColors.shared.value, colors);
      expect(
        () => SavedColors.shared.value.add(const Color(0x00000000)),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'does not restore defaults after the last saved colour is deleted',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async => <int>[]);
      await SavedColors.ensureLoaded();
      expect(SavedColors.shared.value, isEmpty);
    },
  );

  test('a delayed read cannot replace newer user edits', () async {
    final read = Completer<Object?>();
    final writes = <Object?>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getSavedColors') return read.future;
      writes.add(call.arguments);
      return null;
    });
    final loading = SavedColors.ensureLoaded();
    final saving = SavedColors.save(const [Color(0xFF123456)]);
    read.complete([0xFF000000]);
    await loading;
    await saving;
    expect(SavedColors.shared.value, const [Color(0xFF123456)]);
    expect(writes, [
      [0xFF123456],
    ]);
  });

  test('adding before storage loads preserves the persisted palette', () async {
    final read = Completer<Object?>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getSavedColors') return read.future;
      return null;
    });
    final editing = SavedColors.edit(
      (colors) => [...colors, const Color(0xFFABCDEF)],
    );
    read.complete([0xFF123456]);
    expect(await editing, const [Color(0xFF123456), Color(0xFFABCDEF)]);
    expect(SavedColors.shared.value, const [
      Color(0xFF123456),
      Color(0xFFABCDEF),
    ]);
  });

  test('writes stay in edit order when storage is slow', () async {
    final firstWrite = Completer<void>();
    final started = Completer<void>();
    final writes = <Object?>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getSavedColors') return null;
      writes.add(call.arguments);
      if (writes.length == 1) {
        started.complete();
        await firstWrite.future;
      }
      return null;
    });
    final first = SavedColors.save(const [Color(0xFF123456)]);
    await started.future;
    final second = SavedColors.save(const [Color(0xFFABCDEF)]);
    expect(writes, hasLength(1));
    firstWrite.complete();
    await Future.wait([first, second]);
    expect(writes, [
      [0xFF123456],
      [0xFFABCDEF],
    ]);
  });

  for (final bad in [
    <Object?>['red'],
    [-1],
    [0x100000000],
    [null],
    'invalid',
  ]) {
    test('ignores a damaged palette: $bad', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => bad);
      await SavedColors.ensureLoaded();
      expect(SavedColors.shared.value, SavedColors.defaults);
    });
  }

  test(
    'a storage failure preserves edits and does not block later writes',
    () async {
      var writes = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getSavedColors') {
          throw PlatformException(code: 'read_failed');
        }
        if (++writes == 1) throw PlatformException(code: 'write_failed');
        return null;
      });
      await SavedColors.save(const [Color(0xFF123456)]);
      await SavedColors.save(const [Color(0xFFABCDEF)]);
      expect(writes, 2);
      expect(SavedColors.shared.value, const [Color(0xFFABCDEF)]);
    },
  );

  test('a host without the plugin retains its palette in memory', () async {
    await SavedColors.save(const [Color(0xFF123456)]);
    expect(SavedColors.shared.value, const [Color(0xFF123456)]);
  });
}

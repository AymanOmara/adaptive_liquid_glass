import 'dart:io';

import 'package:adaptive_liquid_glass/src/color_picker/saved_colors.dart';
import 'package:adaptive_liquid_glass/src/color_picker/saved_colors_storage.dart';
import 'package:adaptive_liquid_glass/src/color_picker/saved_colors_storage_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStorage implements SavedColorsStorage {
  Object? stored;
  Object? readError;
  Object? writeError;
  final writes = <List<int>>[];

  @override
  Future<Object?> read() async {
    if (readError != null) throw readError!;
    return stored;
  }

  @override
  Future<void> write(List<int> argb) async {
    writes.add(argb);
    if (writeError != null) throw writeError!;
    stored = argb;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JSON codec', () {
    test('round-trips ARGB values, alpha included', () {
      final text = encodeSavedColorsJson(const [0x80123456, 0xFFFFFFFF]);
      expect(decodeSavedColorsJson(text), [0x80123456, 0xFFFFFFFF]);
    });

    test('corrupt or missing text decodes to null', () {
      expect(decodeSavedColorsJson(null), isNull);
      expect(decodeSavedColorsJson(''), isNull);
      expect(decodeSavedColorsJson('[1, 2'), isNull);
    });
  });

  group('desktop file location', () {
    test('macOS: Application Support, namespaced by the app', () {
      expect(
        desktopSavedColorsPath(TargetPlatform.macOS, const {
          'HOME': '/Users/a',
        }, '/Applications/My App.app/Contents/MacOS/My App'),
        '/Users/a/Library/Application Support/My App/'
        'adaptive_liquid_glass/saved_colors.json',
      );
    });

    test(r'Windows: %APPDATA%, without .exe', () {
      expect(
        desktopSavedColorsPath(TargetPlatform.windows, const {
          'APPDATA': r'C:\Users\a\AppData\Roaming',
        }, r'C:\Program Files\demo\demo.exe'),
        r'C:\Users\a\AppData\Roaming\demo\adaptive_liquid_glass'
        r'\saved_colors.json',
      );
    });

    test(r'Linux: $XDG_DATA_HOME, else ~/.local/share', () {
      expect(
        desktopSavedColorsPath(TargetPlatform.linux, const {
          'XDG_DATA_HOME': '/x',
          'HOME': '/home/a',
        }, '/opt/demo/demo'),
        '/x/demo/adaptive_liquid_glass/saved_colors.json',
      );
      expect(
        desktopSavedColorsPath(TargetPlatform.linux, const {
          'HOME': '/home/a',
        }, '/opt/demo/demo'),
        '/home/a/.local/share/demo/adaptive_liquid_glass/saved_colors.json',
      );
    });

    test('no home directory or a mobile platform has no file', () {
      expect(
        desktopSavedColorsPath(TargetPlatform.macOS, const {}, '/a/b'),
        isNull,
      );
      expect(
        desktopSavedColorsPath(TargetPlatform.iOS, const {
          'HOME': '/Users/a',
        }, '/a/b'),
        isNull,
      );
    });

    test('host tests never touch the real user directory', () {
      expect(
        createLocalSavedColorsStorage(
          TargetPlatform.macOS,
          environment: const {'FLUTTER_TEST': 'true', 'HOME': '/Users/a'},
        ),
        isNull,
      );
      expect(
        createLocalSavedColorsStorage(
          TargetPlatform.macOS,
          environment: const {'HOME': '/Users/a'},
          executable: '/a/demo',
        ),
        isA<FileSavedColorsStorage>(),
      );
    });
  });

  group('FileSavedColorsStorage', () {
    late Directory dir;
    late File file;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('alg_palette');
      file = File('${dir.path}/app/adaptive_liquid_glass/saved_colors.json');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('reads nothing before the first save', () async {
      expect(await FileSavedColorsStorage(file).read(), isNull);
    });

    test('saves and reloads, creating the directory', () async {
      await FileSavedColorsStorage(file).write(const [0x80123456, 0]);
      expect(await FileSavedColorsStorage(file).read(), [0x80123456, 0]);
      // The temporary file of the atomic write is gone.
      expect(file.parent.listSync(), hasLength(1));
    });

    test('a corrupt file reads as nothing', () async {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('{"not": "a palette"');
      expect(await FileSavedColorsStorage(file).read(), isNull);
    });

    test('an unwritable location fails silently', () async {
      // The parent "directory" is a file.
      final blocker = File('${dir.path}/blocker')..writeAsStringSync('x');
      final storage = FileSavedColorsStorage(File('${blocker.path}/a.json'));
      await storage.write(const [0xFF000000]);
      expect(await storage.read(), isNull);
    });
  });

  group('SavedColors on desktop and web hosts', () {
    const channel = MethodChannel('adaptive_liquid_glass');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final channelCalls = <MethodCall>[];

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      SavedColors.debugReset();
      channelCalls.clear();
      messenger.setMockMethodCallHandler(channel, (call) async {
        channelCalls.add(call);
        return null;
      });
    });
    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      SavedColors.debugReset();
      debugDefaultTargetPlatformOverride = null;
    });

    test('loads the stored palette and saves edits through storage', () async {
      final storage = _FakeStorage()..stored = [0x80123456];
      SavedColors.debugOverrideStorage(storage);
      await SavedColors.ensureLoaded();
      expect(SavedColors.shared.value, const [Color(0x80123456)]);
      await SavedColors.save(const [Color(0xFFABCDEF)]);
      expect(storage.writes, [
        [0xFFABCDEF],
      ]);
      expect(channelCalls, isEmpty);
    });

    test('a damaged stored palette keeps the defaults', () async {
      SavedColors.debugOverrideStorage(_FakeStorage()..stored = ['red']);
      await SavedColors.ensureLoaded();
      expect(SavedColors.shared.value, SavedColors.defaults);
    });

    test('failing storage falls back to memory silently', () async {
      final storage = _FakeStorage()
        ..readError = const FileSystemException('read')
        ..writeError = Exception('write');
      SavedColors.debugOverrideStorage(storage);
      await SavedColors.save(const [Color(0xFF123456)]);
      await SavedColors.save(const [Color(0xFFABCDEF)]);
      expect(storage.writes, hasLength(2));
      expect(SavedColors.shared.value, const [Color(0xFFABCDEF)]);
    });

    test('without storage the palette stays in memory, off the channel', () {
      SavedColors.debugOverrideStorage(null);
      return SavedColors.save(const [Color(0xFF123456)]).then((_) {
        expect(SavedColors.shared.value, const [Color(0xFF123456)]);
        expect(channelCalls, isEmpty);
      });
    });

    test('the default desktop storage is off under flutter test', () async {
      await SavedColors.save(const [Color(0xFF123456)]);
      expect(SavedColors.shared.value, const [Color(0xFF123456)]);
      expect(channelCalls, isEmpty);
    });
  });
}

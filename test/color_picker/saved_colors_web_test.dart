@TestOn('browser')
library;

import 'package:adaptive_liquid_glass/src/color_picker/saved_colors_storage_web.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const key = 'adaptive_liquid_glass.savedColors.test';

  setUp(() => debugWebLocalStorageRemove(key));
  tearDown(() => debugWebLocalStorageRemove(key));

  test('reads nothing before the first save', () async {
    expect(await const LocalSavedColorsStorage(key).read(), isNull);
  });

  test('saves and reloads through localStorage', () async {
    await const LocalSavedColorsStorage(key).write(const [0x80123456, 0]);
    expect(await const LocalSavedColorsStorage(key).read(), [0x80123456, 0]);
  });

  test('a corrupt entry reads as nothing', () async {
    debugWebLocalStorageSet(key, '[1, 2');
    expect(await const LocalSavedColorsStorage(key).read(), isNull);
  });

  test('the web picks localStorage', () {
    expect(
      createLocalSavedColorsStorage(TargetPlatform.android),
      isA<LocalSavedColorsStorage>(),
    );
  });
}

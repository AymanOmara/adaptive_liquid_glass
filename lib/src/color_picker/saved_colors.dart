import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'saved_colors_storage.dart';

/// The colour picker sheet's saved colours when the app keeps none of its
/// own: shared by every picker and saved locally (natively on iOS and
/// Android, in localStorage on the web, in a JSON file on desktop). Hosts
/// without the plugin or with unavailable storage keep it in memory.
abstract final class SavedColors {
  static bool _storageOverridden = false;
  static SavedColorsStorage? _storageOverride;
  static Future<void>? _loading;
  static Future<void> _writes = Future.value();
  static int _revision = 0;
  static int _generation = 0;

  /// UIColorPickerViewController's saved colours on a fresh iOS 26.4
  /// simulator (measured): black, blue, green, yellow, red.
  static const List<Color> defaults = [
    Color(0xFF000000),
    Color(0xFF0161FD),
    Color(0xFF32C759),
    Color(0xFFFFCC02),
    Color(0xFFFF3A30),
  ];

  /// The shared list.
  static final ValueNotifier<List<Color>> shared = ValueNotifier(defaults);

  /// Loads once, without replacing edits made while storage was being read.
  static Future<void> ensureLoaded() => _loading ??= _load();

  static SavedColorsStorage? get _storage => _storageOverridden
      ? _storageOverride
      : savedColorsStorageFor(web: kIsWeb, platform: defaultTargetPlatform);

  static Future<void> _load() async {
    final storage = _storage;
    if (storage == null) return;
    final generation = _generation;
    final revision = _revision;
    try {
      final stored = await storage.read();
      if (generation != _generation || revision != _revision) return;
      // Reject a damaged palette as a whole. An empty palette is intentional.
      if (stored is! List ||
          stored.any((c) => c is! int || c < 0 || c > 0xFFFFFFFF)) {
        return;
      }
      shared.value = List.unmodifiable(stored.cast<int>().map(Color.new));
    } on Exception {
      // Tests, apps that have not rebuilt the plugin, and temporarily
      // unavailable stores must not prevent picking colours.
    }
  }

  /// Publishes immediately and serializes disk writes in edit order.
  static Future<void> save(List<Color> colors) {
    final next = List<Color>.unmodifiable(colors);
    final loaded = ensureLoaded();
    final storage = _storage;
    final generation = _generation;
    _revision++;
    shared.value = next;
    return _writes = _writes.then((_) async {
      await loaded;
      if (storage == null || generation != _generation) return;
      try {
        await storage.write(next.map((c) => c.toARGB32()).toList());
      } on Exception {
        // Keep the shared in-memory palette when storage is unavailable.
      }
    });
  }

  /// Applies a user edit to the loaded palette, never to placeholder defaults.
  static Future<List<Color>> edit(
    List<Color> Function(List<Color>) update,
  ) async {
    await ensureLoaded();
    final next = List<Color>.unmodifiable(update(shared.value));
    unawaited(save(next));
    return next;
  }

  /// Replaces the platform's storage (null: memory only) until
  /// [debugReset], for tests.
  @visibleForTesting
  static void debugOverrideStorage(SavedColorsStorage? storage) {
    _storageOverridden = true;
    _storageOverride = storage;
  }

  /// Restores [defaults] and the platform's storage, for tests.
  @visibleForTesting
  static void debugReset() {
    _storageOverridden = false;
    _storageOverride = null;
    _generation++;
    _revision = 0;
    _loading = null;
    _writes = Future.value();
    shared.value = defaults;
  }
}

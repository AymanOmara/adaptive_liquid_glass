import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The colour picker sheet's saved colours when the app keeps none of its
/// own: shared by every picker and saved locally on iOS and Android.
/// Unsupported platforms and hosts without the plugin keep it in memory.
abstract final class SavedColors {
  static const _channel = MethodChannel('adaptive_liquid_glass');
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

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  static Future<void> _load() async {
    if (!_supported) return;
    final generation = _generation;
    final revision = _revision;
    try {
      final stored = await _channel.invokeMethod<Object?>('getSavedColors');
      if (generation != _generation || revision != _revision) return;
      // Reject a damaged palette as a whole. An empty palette is intentional.
      if (stored is! List ||
          stored.any((c) => c is! int || c < 0 || c > 0xFFFFFFFF)) {
        return;
      }
      shared.value = List.unmodifiable(stored.cast<int>().map(Color.new));
    } on MissingPluginException {
      // Tests, desktop/web hosts, and apps that have not rebuilt the plugin.
    } on PlatformException {
      // A temporarily unavailable store must not prevent picking colours.
    }
  }

  /// Publishes immediately and serializes disk writes in edit order.
  static Future<void> save(List<Color> colors) {
    final next = List<Color>.unmodifiable(colors);
    final loaded = ensureLoaded();
    final generation = _generation;
    _revision++;
    shared.value = next;
    return _writes = _writes.then((_) async {
      await loaded;
      if (!_supported || generation != _generation) return;
      try {
        await _channel.invokeMethod<void>(
          'setSavedColors',
          next.map((c) => c.toARGB32()).toList(),
        );
      } on MissingPluginException {
        // Keep the shared in-memory palette when there is no native store.
      } on PlatformException {
        // Keep edits usable even when local storage is unavailable.
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

  /// Restores [defaults], for tests.
  @visibleForTesting
  static void debugReset() {
    _generation++;
    _revision = 0;
    _loading = null;
    _writes = Future.value();
    shared.value = defaults;
  }
}

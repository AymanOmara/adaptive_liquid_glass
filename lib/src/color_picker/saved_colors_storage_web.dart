import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import 'saved_colors_storage.dart';

/// The web: the page origin's `localStorage`.
SavedColorsStorage? createLocalSavedColorsStorage(
  TargetPlatform platform, {
  Map<String, String>? environment,
  String? executable,
}) => const LocalSavedColorsStorage();

@JS('window')
external _Window get _window;

extension type _Window._(JSObject _) implements JSObject {
  external _Storage? get localStorage;
}

extension type _Storage._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

/// A palette kept as JSON under [key] in `localStorage`. Storage that is
/// disabled, full or blocked (private browsing, sandboxed iframes) reads as
/// nothing and drops writes, so the picker keeps working from memory.
class LocalSavedColorsStorage implements SavedColorsStorage {
  /// Keeps the palette under [key].
  const LocalSavedColorsStorage([this.key = defaultKey]);

  /// The package's localStorage key.
  static const defaultKey = 'adaptive_liquid_glass.savedColors';

  /// The localStorage key.
  final String key;

  @override
  Future<Object?> read() async {
    try {
      return decodeSavedColorsJson(_window.localStorage?.getItem(key));
    } catch (_) {
      // Accessing localStorage can throw a SecurityError.
      return null;
    }
  }

  @override
  Future<void> write(List<int> argb) async {
    try {
      _window.localStorage?.setItem(key, encodeSavedColorsJson(argb));
    } catch (_) {
      // QuotaExceededError or SecurityError: memory only.
    }
  }
}

/// Sets a raw localStorage entry, for tests.
@visibleForTesting
void debugWebLocalStorageSet(String key, String value) =>
    _window.localStorage?.setItem(key, value);

/// Removes a localStorage entry, for tests.
@visibleForTesting
void debugWebLocalStorageRemove(String key) =>
    _window.localStorage?.removeItem(key);

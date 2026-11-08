import 'dart:convert';

import 'package:flutter/services.dart';

import 'saved_colors_storage_stub.dart'
    if (dart.library.js_interop) 'saved_colors_storage_web.dart'
    if (dart.library.io) 'saved_colors_storage_io.dart';

/// Where the shared saved palette is kept between launches.
abstract interface class SavedColorsStorage {
  /// The stored ARGB values as written, null when nothing usable is stored.
  /// The caller validates the result.
  Future<Object?> read();

  /// Replaces the stored palette with [argb].
  Future<void> write(List<int> argb);
}

/// iOS and Android: the plugin's native store (UserDefaults /
/// SharedPreferences). Throws [MissingPluginException] or
/// [PlatformException] when that store is unavailable.
class ChannelSavedColorsStorage implements SavedColorsStorage {
  /// Creates the native store.
  const ChannelSavedColorsStorage();

  static const _channel = MethodChannel('adaptive_liquid_glass');

  @override
  Future<Object?> read() => _channel.invokeMethod<Object?>('getSavedColors');

  @override
  Future<void> write(List<int> argb) =>
      _channel.invokeMethod<void>('setSavedColors', argb);
}

/// The store for [platform]: native on iOS and Android, localStorage on
/// the web, a JSON file on desktop, none (memory only) elsewhere.
SavedColorsStorage? savedColorsStorageFor({
  required bool web,
  required TargetPlatform platform,
}) {
  if (!web &&
      (platform == TargetPlatform.iOS || platform == TargetPlatform.android)) {
    return const ChannelSavedColorsStorage();
  }
  return createLocalSavedColorsStorage(platform);
}

/// The text form of a palette kept by the web and desktop stores.
String encodeSavedColorsJson(List<int> argb) => jsonEncode(argb);

/// Parses [text] written by [encodeSavedColorsJson]; null when it is missing
/// or not JSON.
Object? decodeSavedColorsJson(String? text) {
  if (text == null || text.isEmpty) return null;
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}

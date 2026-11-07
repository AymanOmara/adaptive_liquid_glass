import 'dart:io';

import 'package:flutter/foundation.dart';

import 'saved_colors_storage.dart';

/// Desktop: a JSON file in the app's data directory (see
/// [desktopSavedColorsPath]). Off under `flutter test`, so host tests never
/// write to the real user directory.
SavedColorsStorage? createLocalSavedColorsStorage(
  TargetPlatform platform, {
  Map<String, String>? environment,
  String? executable,
}) {
  final env = environment ?? Platform.environment;
  if (env.containsKey('FLUTTER_TEST')) return null;
  final path = desktopSavedColorsPath(
    platform,
    env,
    executable ?? Platform.resolvedExecutable,
  );
  return path == null ? null : FileSavedColorsStorage(File(path));
}

/// The saved palette's file on a desktop [platform], or null where there is
/// no data directory. The directory is the per-user one `path_provider`
/// would use (macOS Application Support, inside the sandbox container when
/// sandboxed; Windows `%APPDATA%`; Linux `$XDG_DATA_HOME`), namespaced by
/// the [executable]'s name so apps do not share a palette.
String? desktopSavedColorsPath(
  TargetPlatform platform,
  Map<String, String> env,
  String executable,
) {
  final windows = platform == TargetPlatform.windows;
  final base = switch (platform) {
    TargetPlatform.macOS when env['HOME'] != null =>
      '${env['HOME']}/Library/Application Support',
    TargetPlatform.windows => env['APPDATA'],
    TargetPlatform.linux =>
      _nonEmpty(env['XDG_DATA_HOME']) ??
          (env['HOME'] == null ? null : '${env['HOME']}/.local/share'),
    _ => null,
  };
  if (base == null || base.isEmpty) return null;
  var app = executable.split(windows ? RegExp(r'[\\/]') : '/').last;
  if (windows && app.toLowerCase().endsWith('.exe')) {
    app = app.substring(0, app.length - 4);
  }
  if (app.isEmpty) return null;
  final sep = windows ? r'\' : '/';
  return [base, app, 'adaptive_liquid_glass', 'saved_colors.json'].join(sep);
}

String? _nonEmpty(String? s) => s == null || s.isEmpty ? null : s;

/// A palette kept as JSON in [file]. Any file-system failure or damaged
/// content reads as nothing and writes are dropped, so the picker keeps
/// working from memory.
class FileSavedColorsStorage implements SavedColorsStorage {
  /// Keeps the palette in [file].
  FileSavedColorsStorage(this.file);

  /// The JSON file.
  final File file;

  @override
  Future<Object?> read() async {
    try {
      return decodeSavedColorsJson(await file.readAsString());
    } on IOException {
      return null;
    } on FormatException {
      // Not UTF-8.
      return null;
    }
  }

  @override
  Future<void> write(List<int> argb) async {
    final temp = File('${file.path}.tmp');
    try {
      await file.parent.create(recursive: true);
      await temp.writeAsString(encodeSavedColorsJson(argb), flush: true);
      await temp.rename(file.path);
    } on IOException {
      // Read-only or missing directory: memory only.
    }
  }
}

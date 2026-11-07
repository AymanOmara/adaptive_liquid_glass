import 'package:flutter/foundation.dart';

import 'saved_colors_storage.dart';

/// Hosts with neither `dart:io` nor JS interop keep the palette in memory.
SavedColorsStorage? createLocalSavedColorsStorage(
  TargetPlatform platform, {
  Map<String, String>? environment,
  String? executable,
}) => null;

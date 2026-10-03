import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Loads `liquid_glass.frag` once and shares it.
class GlassProgram {
  GlassProgram._();

  /// The shared instance.
  static final GlassProgram instance = GlassProgram._();

  /// Asset key of the shader inside this package.
  static const String assetKey =
      'packages/adaptive_liquid_glass/shaders/liquid_glass.frag';

  final ValueNotifier<ui.FragmentProgram?> _program = ValueNotifier(null);
  Future<void>? _loading;

  /// The loaded program, or `null` until [load] completes.
  ValueListenable<ui.FragmentProgram?> get program => _program;

  /// Starts loading (idempotent). Failures are reported and may be retried.
  Future<void> load() => _loading ??= ui.FragmentProgram.fromAsset(assetKey)
          .then<void>((p) => _program.value = p)
          .catchError((Object e, StackTrace s) {
        _loading = null;
        FlutterError.reportError(FlutterErrorDetails(
            exception: e, stack: s, library: 'adaptive_liquid_glass'));
      });
}

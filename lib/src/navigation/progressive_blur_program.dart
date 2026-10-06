import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Loads `progressive_blur.frag` once and shares it.
class ProgressiveBlurProgram {
  ProgressiveBlurProgram._();

  /// The shared instance.
  static final ProgressiveBlurProgram instance = ProgressiveBlurProgram._();

  /// Asset key of the shader inside this package.
  static const String assetKey =
      'packages/adaptive_liquid_glass/shaders/progressive_blur.frag';

  final ValueNotifier<ui.FragmentProgram?> _program = ValueNotifier(null);
  Future<void>? _loading;
  bool _skipLoad = false;

  /// The loaded program, or `null` until [load] succeeds.
  ValueListenable<ui.FragmentProgram?> get program => _program;

  /// Starts loading (idempotent). A failure leaves [program] `null` (the
  /// scroll edge then keeps its uniform blur) and lets a later call retry.
  Future<void> load() {
    if (_skipLoad) return Future.value();
    return _loading ??= ui.FragmentProgram.fromAsset(assetKey)
        .then<void>((p) => _program.value = p)
        .catchError((Object e, StackTrace s) {
          _loading = null;
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: e,
              stack: s,
              library: 'adaptive_liquid_glass',
              context: ErrorDescription('loading progressive_blur.frag'),
            ),
          );
        });
  }

  /// Clears the loaded program. With [skipLoad], [load] does nothing.
  @visibleForTesting
  void debugReset({bool skipLoad = false}) {
    _skipLoad = skipLoad;
    _loading = null;
    _program.value = null;
  }
}

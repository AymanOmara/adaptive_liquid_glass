import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Loads `tab_lens_content.frag` once and shares it.
class TabLensProgram {
  TabLensProgram._();

  /// The shared instance.
  static final TabLensProgram instance = TabLensProgram._();

  /// Asset key of the shader inside this package.
  static const String assetKey =
      'packages/adaptive_liquid_glass/shaders/tab_lens_content.frag';

  final ValueNotifier<ui.FragmentProgram?> _program = ValueNotifier(null);
  Future<void>? _loading;
  bool _skipLoad = false;
  int _debugLoadCalls = 0;

  /// The loaded program, or `null` until [load] succeeds.
  ValueListenable<ui.FragmentProgram?> get program => _program;

  /// How many times [load] was called since [debugReset].
  @visibleForTesting
  int get debugLoadCalls => _debugLoadCalls;

  /// Starts loading (idempotent). A failure leaves [program] `null` (the
  /// tab bar then falls back to refracting its copy with the glass) and
  /// lets a later call retry.
  Future<void> load() {
    _debugLoadCalls++;
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
              context: ErrorDescription('loading tab_lens_content.frag'),
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
    _debugLoadCalls = 0;
  }
}

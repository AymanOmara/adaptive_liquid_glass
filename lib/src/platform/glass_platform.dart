import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/glass_environment.dart';

/// Live device facts from the iOS side of the plugin.
class GlassPlatform {
  GlassPlatform._();

  /// The shared instance.
  static final GlassPlatform instance = GlassPlatform._();

  static const MethodChannel _method = MethodChannel('adaptive_liquid_glass');
  static const EventChannel _events =
      EventChannel('adaptive_liquid_glass/reduce_transparency');

  final ValueNotifier<GlassEnvironment> _environment =
      ValueNotifier(GlassEnvironment.current());
  StreamSubscription<Object?>? _subscription;
  bool _started = false;

  /// The current environment; updates when iOS settings change.
  ValueListenable<GlassEnvironment> get environment => _environment;

  /// Starts reading from the platform once. Safe to call repeatedly.
  void ensureStarted() {
    if (_started) return;
    _started = true;
    _environment.value = GlassEnvironment.current();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final map =
          await _method.invokeMapMethod<String, Object?>('getEnvironment');
      if (map != null) {
        _environment.value = _environment.value.copyWith(
          iosMajorVersion: map['iosMajorVersion'] as int?,
          reduceTransparency: map['reduceTransparency'] as bool?,
        );
      }
      _subscription = _events.receiveBroadcastStream().listen((value) {
        _environment.value =
            _environment.value.copyWith(reduceTransparency: value as bool);
      });
    } on PlatformException catch (e, s) {
      FlutterError.reportError(FlutterErrorDetails(
          exception: e, stack: s, library: 'adaptive_liquid_glass'));
    } on MissingPluginException {
      // Running without the iOS plugin (tests, add-to-app); keep defaults.
    }
  }

  /// Resets state between tests.
  @visibleForTesting
  void debugReset() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _started = false;
    _environment.value = GlassEnvironment.current();
  }
}

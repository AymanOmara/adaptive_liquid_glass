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
  static const EventChannel _events = EventChannel(
    'adaptive_liquid_glass/reduce_transparency',
  );

  final ValueNotifier<GlassEnvironment> _environment = ValueNotifier(
    GlassEnvironment.current(),
  );

  /// What the device reports; [environment] is this with
  /// [reduceTransparencyOverride] applied.
  GlassEnvironment _device = GlassEnvironment.current();
  bool? _reduceTransparencyOverride;
  StreamSubscription<Object?>? _subscription;
  bool _started = false;

  /// The current environment; updates when iOS settings change.
  ValueListenable<GlassEnvironment> get environment => _environment;

  /// Replaces the system's Reduce Transparency setting; null follows it.
  bool? get reduceTransparencyOverride => _reduceTransparencyOverride;

  set reduceTransparencyOverride(bool? value) {
    _reduceTransparencyOverride = value;
    _publish();
  }

  void _setDevice(GlassEnvironment value) {
    _device = value;
    _publish();
  }

  void _publish() {
    final override = _reduceTransparencyOverride;
    _environment.value = override == null
        ? _device
        : _device.copyWith(
            reduceTransparency: override,
            reduceTransparencyForced: override,
          );
  }

  /// Starts reading from the platform once. Safe to call repeatedly.
  void ensureStarted() {
    if (_started) return;
    _started = true;
    _setDevice(GlassEnvironment.current());
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final map = await _method.invokeMapMethod<String, Object?>(
        'getEnvironment',
      );
      if (map != null) {
        _setDevice(
          _device.copyWith(
            iosMajorVersion: map['iosMajorVersion'] as int?,
            reduceTransparency: map['reduceTransparency'] as bool?,
          ),
        );
      }
      _subscription = _events.receiveBroadcastStream().listen((value) {
        _setDevice(_device.copyWith(reduceTransparency: value as bool));
      });
    } on PlatformException catch (e, s) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: s,
          library: 'adaptive_liquid_glass',
        ),
      );
    } on MissingPluginException {
      // Running without the iOS plugin (tests, add-to-app); keep defaults.
    }
  }

  /// Replaces the environment in tests and stops platform reads.
  @visibleForTesting
  set debugEnvironment(GlassEnvironment value) {
    _started = true;
    _setDevice(value);
  }

  /// Resets state between tests.
  @visibleForTesting
  void debugReset() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _started = false;
    _reduceTransparencyOverride = null;
    _setDevice(GlassEnvironment.current());
  }
}

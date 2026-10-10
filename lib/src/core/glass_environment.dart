import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'ios_version_stub.dart' if (dart.library.io) 'ios_version_io.dart';

/// Facts about the running device that decide how glass is rendered.
@immutable
class GlassEnvironment {
  /// Creates an environment description.
  const GlassEnvironment({
    required this.platform,
    required this.iosMajorVersion,
    required this.reduceTransparency,
    required this.shaderSupported,
    this.reduceTransparencyForced = false,
  });

  /// Environment known synchronously at startup (no channel data yet).
  ///
  /// The iOS major version is read from `dart:io` here, so the very first
  /// frame already picks native glass on iOS 26+ (no shader-to-native
  /// switch once the platform channel answers).
  factory GlassEnvironment.current() => GlassEnvironment(
    platform: defaultTargetPlatform,
    iosMajorVersion: switch (iosVersionString()) {
      null => null,
      final v => parseIosMajorVersion(v),
    },
    reduceTransparency: false,
    shaderSupported: ui.ImageFilter.isShaderFilterSupported,
  );

  /// The target platform.
  final TargetPlatform platform;

  /// iOS major version, or `null` when unknown or not iOS.
  final int? iosMajorVersion;

  /// Whether iOS Reduce Transparency is on.
  final bool reduceTransparency;

  /// Whether `ImageFilter.shader` is available (Impeller).
  final bool shaderSupported;

  /// Whether the app turned Reduce Transparency on itself
  /// (`AdaptiveLiquidGlass.reduceTransparency`) rather than iOS: native
  /// glass does not see that, so it is drawn opaque by Flutter too.
  final bool reduceTransparencyForced;

  /// Returns a copy with the given fields replaced.
  GlassEnvironment copyWith({
    TargetPlatform? platform,
    int? iosMajorVersion,
    bool? reduceTransparency,
    bool? shaderSupported,
    bool? reduceTransparencyForced,
  }) => GlassEnvironment(
    platform: platform ?? this.platform,
    iosMajorVersion: iosMajorVersion ?? this.iosMajorVersion,
    reduceTransparency: reduceTransparency ?? this.reduceTransparency,
    shaderSupported: shaderSupported ?? this.shaderSupported,
    reduceTransparencyForced:
        reduceTransparencyForced ?? this.reduceTransparencyForced,
  );

  @override
  bool operator ==(Object other) =>
      other is GlassEnvironment &&
      other.platform == platform &&
      other.iosMajorVersion == iosMajorVersion &&
      other.reduceTransparency == reduceTransparency &&
      other.shaderSupported == shaderSupported &&
      other.reduceTransparencyForced == reduceTransparencyForced;

  @override
  int get hashCode => Object.hash(
    platform,
    iosMajorVersion,
    reduceTransparency,
    shaderSupported,
    reduceTransparencyForced,
  );
}

/// The major version in an iOS version string such as
/// `Version 26.4 (Build 23E244)` (`NSProcessInfo`'s
/// `operatingSystemVersionString`, which `dart:io` reports), or null.
int? parseIosMajorVersion(String version) {
  final match = RegExp(r'\d+').firstMatch(version);
  return match == null ? null : int.tryParse(match.group(0)!);
}

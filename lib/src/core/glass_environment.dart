import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Facts about the running device that decide how glass is rendered.
@immutable
class GlassEnvironment {
  /// Creates an environment description.
  const GlassEnvironment({
    required this.platform,
    required this.iosMajorVersion,
    required this.reduceTransparency,
    required this.shaderSupported,
  });

  /// Environment known synchronously at startup (no channel data yet).
  factory GlassEnvironment.current() => GlassEnvironment(
        platform: defaultTargetPlatform,
        iosMajorVersion: null,
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

  /// Returns a copy with the given fields replaced.
  GlassEnvironment copyWith({
    TargetPlatform? platform,
    int? iosMajorVersion,
    bool? reduceTransparency,
    bool? shaderSupported,
  }) =>
      GlassEnvironment(
        platform: platform ?? this.platform,
        iosMajorVersion: iosMajorVersion ?? this.iosMajorVersion,
        reduceTransparency: reduceTransparency ?? this.reduceTransparency,
        shaderSupported: shaderSupported ?? this.shaderSupported,
      );

  @override
  bool operator ==(Object other) =>
      other is GlassEnvironment &&
      other.platform == platform &&
      other.iosMajorVersion == iosMajorVersion &&
      other.reduceTransparency == reduceTransparency &&
      other.shaderSupported == shaderSupported;

  @override
  int get hashCode => Object.hash(
      platform, iosMajorVersion, reduceTransparency, shaderSupported);
}

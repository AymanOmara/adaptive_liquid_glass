import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The material variants of Liquid Glass, mirroring SwiftUI's `Glass`.
enum GlassVariant {
  /// Standard glass: frosted, adapts to the content behind it.
  regular,

  /// Highly transparent glass for rich media backgrounds.
  clear,

  /// No glass effect; the child is shown as is.
  identity,
}

/// An immutable description of a Liquid Glass material.
///
/// Mirrors SwiftUI: `Glass.regular.tint(color).interactive()`.
@immutable
class Glass {
  const Glass._(this.variant, {this.tintColor, this.isInteractive = false});

  /// Standard glass (`Glass.regular`).
  static const Glass regular = Glass._(GlassVariant.regular);

  /// Clear glass (`Glass.clear`).
  static const Glass clear = Glass._(GlassVariant.clear);

  /// No effect (`Glass.identity`).
  static const Glass identity = Glass._(GlassVariant.identity);

  /// Which glass material this is.
  final GlassVariant variant;

  /// Optional tint colour blended into the glass body.
  final Color? tintColor;

  /// Whether the glass reacts to touch (stretch, glow, bounce).
  final bool isInteractive;

  /// Returns a copy tinted with [color]; `null` removes the tint.
  Glass tint(Color? color) =>
      Glass._(variant, tintColor: color, isInteractive: isInteractive);

  /// Returns a copy that reacts to touch when [enabled].
  Glass interactive([bool enabled = true]) =>
      Glass._(variant, tintColor: tintColor, isInteractive: enabled);

  @override
  bool operator ==(Object other) =>
      other is Glass &&
      other.variant == variant &&
      other.tintColor == tintColor &&
      other.isInteractive == isInteractive;

  @override
  int get hashCode => Object.hash(variant, tintColor, isInteractive);

  @override
  String toString() =>
      'Glass.${variant.name}(tint: $tintColor, interactive: $isInteractive)';
}

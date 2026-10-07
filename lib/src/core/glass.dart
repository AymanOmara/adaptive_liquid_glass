import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'glass_colors.dart';
import 'glass_system_colors.dart';
import 'glass_variant.dart';

/// An immutable description of a Liquid Glass material.
///
/// Mirrors SwiftUI's `Glass`: start from a preset and chain modifiers.
///
/// ```dart
/// Glass.regular                          // the default
/// Glass.clear                            // for photos and video
/// Glass.regular.tint(Colors.blue)        // tinted
/// Glass.regular.interactive()            // reacts to touch
/// Glass.clear.tint(Colors.orange).interactive()
///
/// // Named presets, composed from the above:
/// Glass.frosted                          // same as Glass.regular
/// Glass.crystal                          // same as Glass.clear
/// Glass.smoke                            // regular, darkened
/// Glass.accent                           // regular, iOS 26 system blue
/// Glass.tinted(Colors.pink)              // Glass.regular.tint(Colors.pink)
/// Glass.smoke.interactive()              // presets chain like any Glass
/// ```
@immutable
class Glass {
  const Glass._(this.variant, {this.tintColor, bool? interactive})
    : _interactive = interactive;

  /// Standard glass (`Glass.regular`).
  static const Glass regular = Glass._(GlassVariant.regular);

  /// Clear glass (`Glass.clear`).
  static const Glass clear = Glass._(GlassVariant.clear);

  /// No effect (`Glass.identity`).
  static const Glass identity = Glass._(GlassVariant.identity);

  // Named presets. Each is composed from the fields above; none adds a
  // field or changes the shader.

  /// Standard frosted glass: an alias of [regular].
  static const Glass frosted = regular;

  /// Highly transparent glass for photos and video: an alias of [clear].
  static const Glass crystal = clear;

  /// Regular glass darkened with [GlassColors.smokeTint] (black at 35%).
  static const Glass smoke = Glass._(
    GlassVariant.regular,
    tintColor: GlassColors.smokeTint,
  );

  /// Regular glass tinted with iOS 26's system blue
  /// ([GlassSystemColors.blue]).
  static const Glass accent = Glass._(
    GlassVariant.regular,
    tintColor: GlassSystemColors.blue,
  );

  /// Regular glass tinted with [color]: `Glass.regular.tint(color)`.
  static Glass tinted(Color color) => regular.tint(color);

  /// Which glass material this is.
  final GlassVariant variant;

  /// Optional tint colour blended into the glass body.
  final Color? tintColor;

  /// Set by [interactive]; null when never set.
  final bool? _interactive;

  /// Whether the glass reacts to touch (stretch, glow, bounce).
  bool get isInteractive => _interactive ?? false;

  /// Returns a copy tinted with [color]; `null` removes the tint.
  Glass tint(Color? color) =>
      Glass._(variant, tintColor: color, interactive: _interactive);

  /// Returns a copy that reacts to touch when [enabled].
  ///
  /// A `LiquidGlass` with `onPressed` makes its glass interactive; pass
  /// `interactive(false)` to opt out of the press visuals there.
  Glass interactive([bool enabled = true]) =>
      Glass._(variant, tintColor: tintColor, interactive: enabled);

  @override
  bool operator ==(Object other) =>
      other is Glass &&
      other.variant == variant &&
      other.tintColor == tintColor &&
      other._interactive == _interactive;

  @override
  int get hashCode => Object.hash(variant, tintColor, _interactive);

  @override
  String toString() =>
      'Glass.${variant.name}(tint: $tintColor, '
      'interactive: ${_interactive ?? 'unset'})';
}

/// [glass] as used by a pressable `LiquidGlass`: interactive unless it
/// opted out with `interactive(false)`. Internal.
Glass pressableGlass(Glass glass) =>
    glass._interactive == null ? glass.interactive() : glass;

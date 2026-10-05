import 'package:flutter/widgets.dart';

import 'core/glass.dart';
import 'core/glass_shape.dart';
import 'liquid_glass.dart';

/// SwiftUI's `.glassEffect(_:in:)` modifier for any widget.
///
/// ```dart
/// const Text('Hello').glassEffect(padding: const EdgeInsets.all(12));
///
/// const Icon(Icons.add).glassEffect(
///   glass: Glass.clear.interactive(),
///   shape: const GlassShape.circle(),
/// );
/// ```
extension GlassEffect on Widget {
  /// Puts this widget on Liquid Glass; returns a [LiquidGlass].
  ///
  /// [glass] defaults to the theme's `defaultGlass` (regular glass) and
  /// [shape] to a capsule. [glassId] is the morph identity inside a `GlassGroup`
  /// (`glassEffectID`), [unionId] merges members into one shape
  /// (`glassEffectUnion`), and [padding] insets this widget inside the
  /// glass. Use [LiquidGlass] directly for `onPressed` and the other
  /// options.
  LiquidGlass glassEffect({
    Glass? glass,
    GlassShape shape = const GlassShape.capsule(),
    Object? glassId,
    Object? unionId,
    EdgeInsetsGeometry? padding,
  }) => LiquidGlass(
    glass: glass,
    shape: shape,
    glassId: glassId,
    unionId: unionId,
    padding: padding,
    child: this,
  );
}

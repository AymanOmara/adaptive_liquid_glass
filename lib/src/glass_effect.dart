import 'package:flutter/widgets.dart';

import 'core/glass.dart';
import 'core/glass_shape.dart';
import 'core/glass_transition.dart';
import 'liquid_glass.dart';

/// SwiftUI's `.glassEffect(_:in:)` modifier for any widget.
///
/// ```dart
/// const Text('Hello').glassEffect(padding: const EdgeInsets.all(12));
///
/// const Icon(Icons.add).glassEffect(
///   shape: const GlassShape.circle(),
///   padding: const EdgeInsets.all(14),
///   onPressed: add, // a glass button
/// );
/// ```
extension GlassEffect on Widget {
  /// Puts this widget on Liquid Glass; returns a [LiquidGlass].
  ///
  /// [glass] defaults to the theme's `defaultGlass` (regular glass) and
  /// [shape] to a capsule. [glassId] is the morph identity inside a `GlassGroup`
  /// (`glassEffectID`), [unionId] merges members into one shape
  /// (`glassEffectUnion`), [transition] how it appears and goes
  /// (`glassEffectTransition`), and [padding] insets this widget inside the
  /// glass. [onPressed] makes it a button, as on [LiquidGlass.onPressed].
  /// Use [LiquidGlass] directly for the other options.
  LiquidGlass glassEffect({
    Glass? glass,
    GlassShape shape = const GlassShape.capsule(),
    Object? glassId,
    Object? unionId,
    GlassTransition transition = GlassTransition.matchedGeometry,
    EdgeInsetsGeometry? padding,
    VoidCallback? onPressed,
  }) => LiquidGlass(
    glass: glass,
    shape: shape,
    glassId: glassId,
    unionId: unionId,
    transition: transition,
    padding: padding,
    onPressed: onPressed,
    child: this,
  );
}

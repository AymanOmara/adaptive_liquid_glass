import 'package:flutter/widgets.dart';

import 'sheet_metrics.dart';

/// A height a [showGlassSheet] sheet rests at, like SwiftUI's
/// `PresentationDetent`.
@immutable
class GlassSheetDetent {
  const GlassSheetDetent._(this._fraction, this._height, this._large);

  /// About half the screen (`.medium`): floating glass.
  static const GlassSheetDetent medium = GlassSheetDetent._(
    SheetMetrics.mediumFraction,
    null,
    false,
  );

  /// Nearly the whole screen (`.large`): edge to edge and opaque.
  static const GlassSheetDetent large = GlassSheetDetent._(null, null, true);

  /// A fraction of the screen's height (`.fraction(_:)`).
  const GlassSheetDetent.fraction(double fraction)
    : this._(fraction, null, false);

  /// A fixed height in logical pixels (`.height(_:)`).
  const GlassSheetDetent.height(double height) : this._(null, height, false);

  final double? _fraction;
  final double? _height;
  final bool _large;

  /// The distance from the sheet's top edge to the screen's bottom on a
  /// screen of [size] whose status bar is [topPadding] tall.
  double resolve(Size size, double topPadding) {
    final large = size.height - topPadding;
    final value = _large
        ? large
        : _height ?? (_fraction ?? SheetMetrics.mediumFraction) * size.height;
    return value.clamp(0.0, large);
  }

  @override
  bool operator ==(Object other) =>
      other is GlassSheetDetent &&
      other._fraction == _fraction &&
      other._height == _height &&
      other._large == _large;

  @override
  int get hashCode => Object.hash(_fraction, _height, _large);
}

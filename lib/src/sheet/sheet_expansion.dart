import 'sheet_metrics.dart';

/// How far a sheet [height] tall (its top edge's distance from the
/// screen's bottom) has morphed from floating glass (0) to the large,
/// edge-to-edge sheet (1), given its resting [stops] (lowest first) and
/// the [medium] and [large] detents' heights on this screen.
///
/// SwiftUI floats every partial detent 8 pt in from the screen's sides,
/// whatever its height (`.height(300)` to `.height(765)` measured on iOS
/// 26.4); only a detent within [SheetMetrics.edgeToEdgeGap] of large runs
/// edge to edge. Between its tallest floating stop (medium when it has
/// none) and its first edge-to-edge one (large when it has none) a
/// dragged sheet morphs from one to the other.
double sheetExpansion(
  double height,
  List<double> stops, {
  required double medium,
  required double large,
}) {
  final edge = large - SheetMetrics.edgeToEdgeGap;
  final floating = stops.where((s) => s < edge);
  final full = stops.where((s) => s >= edge);
  final from = floating.isEmpty ? medium : floating.last;
  final to = full.isEmpty ? large : full.first;
  if (to <= from) return 1;
  return ((height - from) / (to - from)).clamp(0.0, 1.0);
}

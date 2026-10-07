import 'package:flutter/widgets.dart';

import '../core/glass_colors.dart';
import 'color_hex.dart';
import 'color_picker_metrics.dart';

/// The preset grid of iOS's colour picker: a row of greys from white to
/// black, then rows of hues from light to dark (estimated against iOS
/// 26's 12 × 10 grid; see [ColorPickerMetrics.gridRows]).
class ColorSwatchGrid extends StatelessWidget {
  /// Creates the grid.
  const ColorSwatchGrid({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  /// The colour drawn with a selection ring, when it is one of the grid's.
  final Color selected;

  /// Called with the tapped swatch's colour.
  final ValueChanged<Color> onSelected;

  /// The grid's colours, row by row.
  static List<List<Color>> colors() {
    const columns = ColorPickerMetrics.gridColumns;
    const rows = ColorPickerMetrics.gridRows;
    // Saturation and value per hue row, light to dark.
    const shades = <(double, double)>[
      (0.35, 1.0),
      (0.6, 1.0),
      (1.0, 1.0),
      (1.0, 0.75),
      (1.0, 0.5),
    ];
    return [
      [
        for (var c = 0; c < columns; c++)
          HSVColor.fromAHSV(1, 0, 0, 1 - c / (columns - 1)).toColor(),
      ],
      for (var r = 0; r < rows - 1; r++)
        [
          for (var c = 0; c < columns; c++)
            HSVColor.fromAHSV(
              1,
              c * 360 / columns,
              shades[r % shades.length].$1,
              shades[r % shades.length].$2,
            ).toColor(),
        ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rows = colors();
    final opaque = selected.withValues(alpha: 1).toARGB32();
    return ClipRRect(
      borderRadius: BorderRadius.circular(ColorPickerMetrics.gridRadius),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < rows.length; r++)
            Padding(
              padding: EdgeInsets.only(
                bottom: r == rows.length - 1 ? 0 : ColorPickerMetrics.gridGap,
              ),
              child: Row(
                children: [
                  for (var c = 0; c < rows[r].length; c++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(
                          end: c == rows[r].length - 1
                              ? 0
                              : ColorPickerMetrics.gridGap,
                        ),
                        child: _Swatch(
                          color: rows[r][c],
                          selected: rows[r][c].toARGB32() == opaque,
                          onTap: () => onSelected(rows[r][c]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      button: true,
      selected: selected,
      label: formatHexColor(color),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 1,
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : ColorPickerMetrics.selectionDuration,
            decoration: BoxDecoration(
              color: color,
              border: selected
                  ? Border.all(
                      color: GlassColors.colorPickerSelection,
                      width: ColorPickerMetrics.gridSelectionRing,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

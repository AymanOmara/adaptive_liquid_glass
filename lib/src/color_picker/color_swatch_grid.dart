import 'package:flutter/widgets.dart';

import '../core/glass_colors.dart';
import 'color_hex.dart';
import 'color_picker_metrics.dart';

part 'color_swatch.dart';

/// The preset grid of iOS's colour picker: a row of greys from white to
/// black, then nine rows of hues from dark to light, UIKit's own 12 x 10
/// colours (sampled from UIColorPickerViewController, iOS 26.4) in one
/// edge-to-edge block with rounded outer corners.
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
  static List<List<Color>> colors() => [
    const [
      Color(0xFFFFFFFF),
      Color(0xFFEBEBEB),
      Color(0xFFD6D6D6),
      Color(0xFFC2C2C2),
      Color(0xFFADADAD),
      Color(0xFF999999),
      Color(0xFF858585),
      Color(0xFF707070),
      Color(0xFF5C5C5C),
      Color(0xFF474747),
      Color(0xFF333333),
      Color(0xFF000000),
    ],
    const [
      Color(0xFF00374A),
      Color(0xFF011D57),
      Color(0xFF11053B),
      Color(0xFF2E063D),
      Color(0xFF3C071B),
      Color(0xFF5C0701),
      Color(0xFF5A1C00),
      Color(0xFF583300),
      Color(0xFF563D00),
      Color(0xFF666100),
      Color(0xFF4F5504),
      Color(0xFF263E0F),
    ],
    const [
      Color(0xFF004D65),
      Color(0xFF012F7B),
      Color(0xFF1A0A52),
      Color(0xFF450D59),
      Color(0xFF551029),
      Color(0xFF831100),
      Color(0xFF7B2900),
      Color(0xFF7A4A00),
      Color(0xFF785800),
      Color(0xFF8D8602),
      Color(0xFF6F760A),
      Color(0xFF38571A),
    ],
    const [
      Color(0xFF016E8F),
      Color(0xFF0042A9),
      Color(0xFF2C0977),
      Color(0xFF61187C),
      Color(0xFF791A3D),
      Color(0xFFB51A00),
      Color(0xFFAD3E00),
      Color(0xFFA96800),
      Color(0xFFA67B01),
      Color(0xFFC4BC00),
      Color(0xFF9BA50E),
      Color(0xFF4E7A27),
    ],
    const [
      Color(0xFF008CB4),
      Color(0xFF0056D6),
      Color(0xFF371A94),
      Color(0xFF7A219E),
      Color(0xFF99244F),
      Color(0xFFE22400),
      Color(0xFFDA5100),
      Color(0xFFD38301),
      Color(0xFFD19D01),
      Color(0xFFF5EC00),
      Color(0xFFC3D117),
      Color(0xFF669D34),
    ],
    const [
      Color(0xFF00A1D8),
      Color(0xFF0061FE),
      Color(0xFF4D22B2),
      Color(0xFF982ABC),
      Color(0xFFB92D5D),
      Color(0xFFFF4015),
      Color(0xFFFF6A00),
      Color(0xFFFFAB01),
      Color(0xFFFDC700),
      Color(0xFFFEFB41),
      Color(0xFFD9EC37),
      Color(0xFF76BB40),
    ],
    const [
      Color(0xFF01C7FC),
      Color(0xFF3A87FE),
      Color(0xFF5E30EB),
      Color(0xFFBE38F3),
      Color(0xFFE63B7A),
      Color(0xFFFF6250),
      Color(0xFFFF8648),
      Color(0xFFFEB43F),
      Color(0xFFFECB3E),
      Color(0xFFFFF76B),
      Color(0xFFE4EF65),
      Color(0xFF96D35F),
    ],
    const [
      Color(0xFF52D6FC),
      Color(0xFF74A7FF),
      Color(0xFF864FFE),
      Color(0xFFD357FE),
      Color(0xFFEE719E),
      Color(0xFFFF8C82),
      Color(0xFFFFA57D),
      Color(0xFFFFC777),
      Color(0xFFFFD977),
      Color(0xFFFFF994),
      Color(0xFFEAF28F),
      Color(0xFFB1DD8B),
    ],
    const [
      Color(0xFF93E3FD),
      Color(0xFFA7C6FF),
      Color(0xFFB18CFE),
      Color(0xFFE292FE),
      Color(0xFFF4A4C0),
      Color(0xFFFFB5AF),
      Color(0xFFFFC5AB),
      Color(0xFFFFD9A8),
      Color(0xFFFEE4A8),
      Color(0xFFFFFBB9),
      Color(0xFFF2F7B7),
      Color(0xFFCDE8B5),
    ],
    const [
      Color(0xFFCBF0FF),
      Color(0xFFD3E2FF),
      Color(0xFFD9C9FE),
      Color(0xFFEFCAFF),
      Color(0xFFF9D3E0),
      Color(0xFFFFDBD8),
      Color(0xFFFFE2D6),
      Color(0xFFFFECD4),
      Color(0xFFFFF2D5),
      Color(0xFFFEFCDD),
      Color(0xFFF7FADB),
      Color(0xFFDFEED4),
    ],
  ];

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

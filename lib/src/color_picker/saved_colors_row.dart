import 'package:flutter/cupertino.dart';

import '../context_menu/glass_context_menu.dart';
import '../core/glass_colors.dart';
import '../menu/glass_menu_item.dart';
import 'checkerboard_painter.dart';
import 'color_hex.dart';
import 'color_picker_metrics.dart';

/// UIColorPickerViewController's saved colours beside the current colour:
/// a row of round swatches and a "+" that saves the current colour
/// (measured: 29-pt circles 46.07 apart, level with the current swatch's
/// top). A tap picks a saved colour; a long press opens UIKit's context
/// menu with Delete. It scrolls
/// sideways once it outgrows the sheet.
class SavedColorsRow extends StatelessWidget {
  /// Creates the row.
  const SavedColorsRow({
    super.key,
    required this.colors,
    required this.onPick,
    required this.onAdd,
    required this.onRemove,
    this.savedLabel = 'Saved colour',
    this.addLabel = 'Add to saved colours',
    this.deleteLabel = 'Delete',
  });

  /// The saved colours, in order.
  final List<Color> colors;

  /// Called with a tapped colour.
  final ValueChanged<Color> onPick;

  /// Called by the "+".
  final VoidCallback onAdd;

  /// Called with the index of a colour deleted from its context menu.
  final ValueChanged<int> onRemove;

  /// A saved colour's screen-reader label, before its hex code.
  final String savedLabel;

  /// The "+" button's screen-reader label.
  final String addLabel;

  /// The context menu's delete item.
  final String deleteLabel;

  static const double _gap =
      ColorPickerMetrics.savedPitch - ColorPickerMetrics.savedSwatch;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: ColorPickerMetrics.savedSwatch,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.zero,
      children: [
        for (var i = 0; i < colors.length; i++) ...[
          Semantics(
            button: true,
            label: '$savedLabel ${formatHexColor(colors[i])}',
            child: GlassContextMenu(
              items: [
                GlassMenuItem(
                  label: deleteLabel,
                  icon: CupertinoIcons.trash,
                  destructive: true,
                  onSelected: () => onRemove(i),
                ),
              ],
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onPick(colors[i]),
                child: _Circle(color: colors[i]),
              ),
            ),
          ),
          const SizedBox(width: _gap),
        ],
        Semantics(
          button: true,
          label: addLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAdd,
            child: Container(
              width: ColorPickerMetrics.savedSwatch,
              height: ColorPickerMetrics.savedSwatch,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: GlassColors.colorPickerAddFill,
              ),
              child: const CustomPaint(
                painter: _PlusPainter(GlassColors.colorPickerAddGlyph),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Circle extends StatelessWidget {
  const _Circle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => ClipOval(
    child: CustomPaint(
      painter: color.a < 1 ? const CheckerboardPainter() : null,
      child: SizedBox.square(
        dimension: ColorPickerMetrics.savedSwatch,
        child: ColoredBox(color: color),
      ),
    ),
  );
}

/// The "+" glyph (measured: 13.67 pt across, 2.33-pt strokes).
class _PlusPainter extends CustomPainter {
  const _PlusPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const h = ColorPickerMetrics.savedPlus / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = ColorPickerMetrics.savedPlusStroke
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(
        c.translate(-h + ColorPickerMetrics.savedPlusStroke / 2, 0),
        c.translate(h - ColorPickerMetrics.savedPlusStroke / 2, 0),
        paint,
      )
      ..drawLine(
        c.translate(0, -h + ColorPickerMetrics.savedPlusStroke / 2),
        c.translate(0, h - ColorPickerMetrics.savedPlusStroke / 2),
        paint,
      );
  }

  @override
  bool shouldRepaint(_PlusPainter old) => old.color != color;
}

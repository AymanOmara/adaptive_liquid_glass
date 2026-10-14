part of 'color_swatch_grid.dart';

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

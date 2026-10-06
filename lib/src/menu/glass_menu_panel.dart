import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import '../core/glass_render_mode.dart';
import '../core/glass_shape.dart';
import '../group/glass_group.dart';
import '../liquid_glass.dart';
import 'glass_menu_item.dart';
import 'glass_menu_row.dart';
import 'menu_metrics.dart';

/// The glass panel of a menu: its rows on a [MenuMetrics.width] card.
class GlassMenuPanel extends StatelessWidget {
  /// Creates the panel; [onChoose] runs when a row is tapped.
  const GlassMenuPanel({
    super.key,
    required this.items,
    required this.onChoose,
    this.mode,
    this.highlighted,
  });

  /// The rows, top to bottom.
  final List<GlassMenuItem> items;

  /// Called with the tapped item.
  final ValueChanged<GlassMenuItem> onChoose;

  /// The rendering path.
  final GlassRenderMode? mode;

  /// The row a glide highlights, if any; see [GlassMenuController].
  final ValueListenable<int?>? highlighted;

  @override
  Widget build(BuildContext context) {
    final choices = items.any((i) => i.checked != null);
    return SizedBox(
      width: MenuMetrics.width,
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        // Its own group: an overlay inherits its opener's scopes, and in a
        // bar's group the menu would merge with the buttons' capsule.
        child: GlassGroup(
          mode: mode,
          child: LiquidGlass(
            mode: mode,
            shape: const GlassShape.rect(MenuMetrics.cornerRadius),
            padding: const EdgeInsets.symmetric(
              vertical: MenuMetrics.verticalPadding,
            ),
            child: _rows(choices),
          ),
        ),
      ),
    );
  }

  Widget _rows(bool choices) {
    Widget column(int? highlight) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++)
          GlassMenuRow(
            item: items[i],
            choices: choices,
            highlighted: highlight == i,
            onTap: items[i].onSelected == null
                ? null
                : () => onChoose(items[i]),
          ),
      ],
    );
    final listenable = highlighted;
    if (listenable == null) return column(null);
    return ValueListenableBuilder<int?>(
      valueListenable: listenable,
      builder: (context, value, _) => column(value),
    );
  }
}

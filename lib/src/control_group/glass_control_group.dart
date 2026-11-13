import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;

import '../button/glass_button_metrics_scope.dart';
import '../core/effective_glass_mode.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../group/glass_group.dart';
import '../group/glass_union_scope.dart';
import '../menu/glass_menu_button.dart';
import '../menu/glass_menu_item.dart';
import 'control_group_metrics.dart';

/// Related glass buttons in one capsule, like SwiftUI's `ControlGroup`.
///
/// ```dart
/// GlassControlGroup(
///   children: [
///     GlassButton.icon(onPressed: back, icon: CupertinoIcons.chevron_up,
///         semanticLabel: 'Previous'),
///     GlassButton.icon(onPressed: next, icon: CupertinoIcons.chevron_down,
///         semanticLabel: 'Next'),
///   ],
/// )
/// ```
///
/// The buttons merge into one capsule, with a divider between them
/// ([dividers]). Pass the group as a toolbar or navigation bar item to
/// keep it one capsule there. [GlassControlGroup.menu] is SwiftUI's
/// `.controlGroupStyle(.menu)`: one button that opens the members as a
/// pull-down menu.
///
/// Sizes are the toolbar's grouped items (measured, `ControlGroupMetrics`).
/// On the Material path the buttons sit in a Material 3 segmented surface.
class GlassControlGroup extends StatelessWidget {
  /// Creates a capsule of [children], usually icon-only `GlassButton`s.
  const GlassControlGroup({
    super.key,
    required List<Widget> this.children,
    this.dividers = true,
    this.mode,
  }) : items = null,
       menuIcon = null,
       menuSemanticLabel = null;

  /// Creates a single button that opens [items] as a menu.
  const GlassControlGroup.menu({
    super.key,
    required List<GlassMenuItem> this.items,
    this.menuIcon = CupertinoIcons.ellipsis,
    this.menuSemanticLabel = 'More',
    this.mode,
  }) : children = null,
       dividers = false;

  /// The buttons, in reading order.
  final List<Widget>? children;

  /// The menu's items ([GlassControlGroup.menu]).
  final List<GlassMenuItem>? items;

  /// The menu button's icon.
  final IconData? menuIcon;

  /// What assistive tech reads for the menu button.
  final String? menuSemanticLabel;

  /// Whether a thin line separates neighbours.
  final bool dividers;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  Widget build(BuildContext context) {
    final menuItems = items;
    if (menuItems != null) {
      return GlassMenuButton(
        icon: menuIcon!,
        semanticLabel: menuSemanticLabel!,
        items: menuItems,
        mode: mode,
      );
    }
    final members = children!;
    return GlassModeBuilder(
      mode: mode,
      builder: (context, effective) {
        final material = effective == EffectiveGlassMode.material;
        final row = <Widget>[];
        for (var i = 0; i < members.length; i++) {
          if (i > 0 && dividers) row.add(_divider(context, material));
          row.add(members[i]);
        }
        final content = Row(mainAxisSize: MainAxisSize.min, children: row);
        if (material) {
          return Semantics(
            container: true,
            child: Material(
              type: MaterialType.card,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: content,
            ),
          );
        }
        return Semantics(
          container: true,
          child: GlassButtonMetricsScope(
            metrics: ControlGroupMetrics.item,
            child: GlassGroup(
              mode: mode,
              child: GlassUnionScope(id: this, child: content),
            ),
          ),
        );
      },
    );
  }

  Widget _divider(BuildContext context, bool material) => Container(
    width: ControlGroupMetrics.dividerWidth,
    height: ControlGroupMetrics.dividerHeight,
    color: CupertinoDynamicColor.resolve(GlassColors.stepperDivider, context),
  );
}

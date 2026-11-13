import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        ButtonStyle,
        MaterialTapTargetSize,
        VisualDensity,
        Divider,
        IconButton,
        Icons,
        MenuAnchor,
        MenuController,
        MenuItemButton,
        SubmenuButton,
        Theme,
        Tooltip,
        TooltipTriggerMode;

import '../button/glass_button.dart';
import '../core/effective_glass_mode.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import 'glass_menu_anchor.dart';
import 'glass_menu_placement.dart';
import 'glass_menu_controller.dart';
import 'glass_menu_controller_host.dart';
import 'glass_menu_item.dart';
import 'menu_sections.dart';

part 'material_menu.dart';

/// An icon button that opens an iOS 26 pull-down menu: a glass panel that
/// springs out of the button.
///
/// ```dart
/// GlassMenuButton(
///   items: [
///     GlassMenuItem(label: 'Copy', icon: CupertinoIcons.doc_on_doc,
///         onSelected: copy),
///     GlassMenuItem(label: 'Delete', icon: CupertinoIcons.trash,
///         destructive: true, onSelected: delete),
///   ],
/// )
/// ```
///
/// The menu opens over the button, from its top corner (its bottom corner
/// near the bottom of the screen) on the button's nearer side, as SwiftUI's
/// `Menu` does. Measured from SwiftUI (`MenuMetrics`). Tap outside or choose an
/// item to close it. On the Material path it is a Material 3 [MenuAnchor].
/// Without [icon] and [semanticLabel] it is the "More" ellipsis button.
///
/// With [primaryAction] it is SwiftUI's `Menu(primaryAction:)`: a tap runs
/// the action and a long-press opens the menu.
///
/// On Android the button is a Material [IconButton] (48 pt with its tap
/// target); [materialStyle] restyles it, e.g. [compactMaterialStyle] for a
/// 32-pt host such as a list row.
class GlassMenuButton extends StatelessWidget {
  /// Creates a menu button.
  const GlassMenuButton({
    super.key,
    this.icon = CupertinoIcons.ellipsis,
    this.semanticLabel = 'More',
    required this.items,
    this.controller,
    this.mode,
    this.primaryAction,
    this.materialStyle,
    this.placement = GlassMenuPlacement.corner,
  });

  /// A Material [IconButton] style for 32-pt hosts: a 32-pt button with an
  /// 18-pt icon, no padding and a shrink-wrapped tap target.
  static const ButtonStyle compactMaterialStyle = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size.square(32)),
    maximumSize: WidgetStatePropertyAll(Size.square(32)),
    fixedSize: WidgetStatePropertyAll(Size.square(32)),
    padding: WidgetStatePropertyAll(EdgeInsets.zero),
    iconSize: WidgetStatePropertyAll(18),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
  );

  /// The button's icon; defaults to an ellipsis.
  final IconData icon;

  /// What assistive tech reads for the button; defaults to 'More'.
  final String semanticLabel;

  /// The menu's items, top to bottom.
  final List<GlassMenuItem> items;

  /// External control; see [GlassMenuController]. Gliding is a no-op on
  /// the Material path.
  final GlassMenuController? controller;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// What a tap runs, as SwiftUI's `Menu(primaryAction:)`; the menu then
  /// opens on a long-press. Null: a tap opens the menu.
  final VoidCallback? primaryAction;

  /// The Material path's [IconButton] style, merged over the theme's (e.g.
  /// [compactMaterialStyle]). Ignored on the glass paths.
  final ButtonStyle? materialStyle;

  /// Where the menu opens relative to this button.
  final GlassMenuPlacement placement;

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) => effective == EffectiveGlassMode.material
        ? _MaterialMenu(
            icon: icon,
            semanticLabel: semanticLabel,
            items: items,
            controller: controller,
            primaryAction: primaryAction,
            style: materialStyle,
          )
        : GlassMenuAnchor(
            items: items,
            mode: mode,
            controller: controller,
            placement: placement,
            builder: (context, open) {
              final button = GlassButton.icon(
                onPressed: primaryAction ?? open,
                icon: icon,
                semanticLabel: semanticLabel,
                mode: mode,
              );
              if (primaryAction == null) return button;
              return GestureDetector(onLongPress: open, child: button);
            },
          ),
  );
}

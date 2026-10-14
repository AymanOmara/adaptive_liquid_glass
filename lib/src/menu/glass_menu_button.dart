import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show IconButton, MenuAnchor, MenuController, MenuItemButton, Theme;

import '../button/glass_button.dart';
import '../core/effective_glass_mode.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import 'glass_menu_anchor.dart';
import 'glass_menu_controller.dart';
import 'glass_menu_controller_host.dart';
import 'glass_menu_item.dart';

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
class GlassMenuButton extends StatelessWidget {
  /// Creates a menu button.
  const GlassMenuButton({
    super.key,
    this.icon = CupertinoIcons.ellipsis,
    this.semanticLabel = 'More',
    required this.items,
    this.controller,
    this.mode,
  });

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

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) => effective == EffectiveGlassMode.material
        ? _MaterialMenu(
            icon: icon,
            semanticLabel: semanticLabel,
            items: items,
            controller: controller,
          )
        : GlassMenuAnchor(
            items: items,
            mode: mode,
            controller: controller,
            builder: (context, open) => GlassButton.icon(
              onPressed: open,
              icon: icon,
              semanticLabel: semanticLabel,
              mode: mode,
            ),
          ),
  );
}

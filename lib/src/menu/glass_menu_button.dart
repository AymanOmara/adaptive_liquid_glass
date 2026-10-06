import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show IconButton, MenuAnchor, MenuItemButton;

import '../button/glass_button.dart';
import '../core/effective_glass_mode.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import 'glass_menu_anchor.dart';
import 'glass_menu_item.dart';

/// An icon button that opens an iOS 26 pull-down menu: a glass panel that
/// springs out of the button.
///
/// ```dart
/// GlassMenuButton(
///   icon: CupertinoIcons.ellipsis,
///   semanticLabel: 'More',
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
class GlassMenuButton extends StatelessWidget {
  /// Creates a menu button.
  const GlassMenuButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.items,
    this.mode,
  });

  /// The button's icon.
  final IconData icon;

  /// What assistive tech reads for the button.
  final String semanticLabel;

  /// The menu's items, top to bottom.
  final List<GlassMenuItem> items;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) => effective == EffectiveGlassMode.material
        ? _material()
        : GlassMenuAnchor(
            items: items,
            mode: mode,
            builder: (context, open) => GlassButton.icon(
              onPressed: open,
              icon: icon,
              semanticLabel: semanticLabel,
              mode: mode,
            ),
          ),
  );

  Widget _material() => MenuAnchor(
    menuChildren: [
      for (final item in items)
        MenuItemButton(
          onPressed: item.onSelected,
          leadingIcon: item.icon == null ? null : Icon(item.icon),
          child: Text(item.label),
        ),
    ],
    builder: (context, controller, _) => IconButton(
      icon: Icon(icon),
      tooltip: semanticLabel,
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
    ),
  );
}

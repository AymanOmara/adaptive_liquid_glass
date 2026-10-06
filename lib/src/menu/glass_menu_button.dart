import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show IconButton, MenuAnchor, MenuController, MenuItemButton;

import '../button/glass_button.dart';
import '../core/effective_glass_mode.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import 'glass_menu_anchor.dart';
import 'glass_menu_controller.dart';
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
    this.controller,
    this.mode,
  });

  /// The button's icon.
  final IconData icon;

  /// What assistive tech reads for the button.
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

/// The Material menu under external control: opening and closing drive
/// the Material menu; gliding does nothing (a slide needs the rows under
/// the finger, which Material's panel does not report).
class _MaterialMenu extends StatefulWidget {
  const _MaterialMenu({
    required this.icon,
    required this.semanticLabel,
    required this.items,
    this.controller,
  });

  final IconData icon;
  final String semanticLabel;
  final List<GlassMenuItem> items;
  final GlassMenuController? controller;

  @override
  State<_MaterialMenu> createState() => _MaterialMenuState();
}

class _MaterialMenuState extends State<_MaterialMenu>
    implements GlassMenuControllerHost {
  final MenuController _menuController = MenuController();

  @override
  void initState() {
    super.initState();
    widget.controller?.attach(this);
  }

  @override
  void didUpdateWidget(covariant _MaterialMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?.detach(this);
      widget.controller?.attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?.detach(this);
    super.dispose();
  }

  @override
  bool get isOpen => _menuController.isOpen;

  @override
  void open() => _menuController.open();

  @override
  void close() => _menuController.close();

  @override
  bool glideTo(Offset globalPosition) => false;

  @override
  bool endGlide() => false;

  @override
  void cancelGlide() {}

  @override
  Widget build(BuildContext context) => MenuAnchor(
    controller: _menuController,
    menuChildren: [
      for (final item in widget.items)
        MenuItemButton(
          onPressed: item.onSelected,
          leadingIcon: item.icon == null ? null : Icon(item.icon),
          child: Text(item.label),
        ),
    ],
    builder: (context, controller, _) => IconButton(
      icon: Icon(widget.icon),
      tooltip: widget.semanticLabel,
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
    ),
  );
}

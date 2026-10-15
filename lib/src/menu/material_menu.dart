part of 'glass_menu_button.dart';

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
          style: item.destructive
              ? MenuItemButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  iconColor: Theme.of(context).colorScheme.error,
                )
              : item.color != null
              ? MenuItemButton.styleFrom(
                  foregroundColor: item.color,
                  iconColor: item.color,
                )
              : null,
          child: Semantics(
            label: item.semanticLabel,
            excludeSemantics: item.semanticLabel != null,
            child: Text(item.label),
          ),
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

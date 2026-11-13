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
    this.primaryAction,
  });

  final IconData icon;
  final String semanticLabel;
  final List<GlassMenuItem> items;
  final GlassMenuController? controller;
  final VoidCallback? primaryAction;

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
    menuChildren: _materialMenuChildren(context, widget.items),
    builder: (context, controller, _) {
      void toggle() =>
          controller.isOpen ? controller.close() : controller.open();
      final primary = widget.primaryAction;
      if (primary == null) {
        return IconButton(
          icon: Icon(widget.icon),
          tooltip: widget.semanticLabel,
          onPressed: toggle,
        );
      }
      // The long-press opens the menu, so the tooltip must not claim it.
      return Tooltip(
        message: widget.semanticLabel,
        triggerMode: TooltipTriggerMode.manual,
        child: GestureDetector(
          onLongPress: toggle,
          child: IconButton(icon: Icon(widget.icon), onPressed: primary),
        ),
      );
    },
  );
}

/// The Material rows of [items]: a section's rows in a group, a divider
/// between sections and its title as a label; a submenu as a
/// [SubmenuButton].
List<Widget> _materialMenuChildren(
  BuildContext context,
  List<GlassMenuItem> items,
) {
  final sections = menuSections(items);
  final theme = Theme.of(context);
  return [
    for (var s = 0; s < sections.length; s++) ...[
      if (s > 0) const Divider(height: 1),
      if (sections[s].title case final title?)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 4),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      for (final item in sections[s].rows)
        if (item.isSubmenu)
          SubmenuButton(
            leadingIcon: item.icon == null ? null : Icon(item.icon),
            menuChildren: _materialMenuChildren(context, item.children),
            child: _materialLabel(item),
          )
        else
          MenuItemButton(
            onPressed: item.onSelected,
            leadingIcon: item.icon == null ? null : Icon(item.icon),
            trailingIcon: item.checked == true ? const Icon(Icons.check) : null,
            style: item.destructive
                ? MenuItemButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    iconColor: theme.colorScheme.error,
                  )
                : item.color != null
                ? MenuItemButton.styleFrom(
                    foregroundColor: item.color,
                    iconColor: item.color,
                  )
                : null,
            child: _materialLabel(item),
          ),
    ],
  ];
}

Widget _materialLabel(GlassMenuItem item) => Semantics(
  label: item.semanticLabel,
  excludeSemantics: item.semanticLabel != null,
  child: Text(item.label),
);

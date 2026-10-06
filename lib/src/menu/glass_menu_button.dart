import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show IconButton, MenuAnchor, MenuItemButton;
import 'package:flutter/physics.dart';

import '../button/glass_button.dart';
import '../core/effective_glass_mode.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_shape.dart';
import '../group/glass_group.dart';
import '../liquid_glass.dart';
import 'glass_menu_item.dart';
import 'glass_menu_row.dart';
import 'menu_metrics.dart';

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
/// The menu opens below the button (above it near the bottom of the
/// screen), aligned to the button's nearer side. Tap outside or choose an
/// item to close it. On the Material path it is a Material 3 [MenuAnchor].
class GlassMenuButton extends StatefulWidget {
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
  State<GlassMenuButton> createState() => _GlassMenuButtonState();
}

class _GlassMenuButtonState extends State<GlassMenuButton>
    with SingleTickerProviderStateMixin {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  late final AnimationController _open = AnimationController.unbounded(
    vsync: this,
  );

  /// Where the menu hangs from the button.
  Alignment _buttonAnchor = Alignment.bottomRight;
  Alignment _menuAnchor = Alignment.topRight;

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _show() {
    final box = context.findRenderObject()! as RenderBox;
    final centre = box.localToGlobal(box.size.center(Offset.zero));
    final screen = MediaQuery.sizeOf(context);
    final below = centre.dy < screen.height * 0.6;
    final right = centre.dx > screen.width / 2;
    final x = right ? 1.0 : -1.0;
    _buttonAnchor = Alignment(x, below ? 1 : -1);
    _menuAnchor = Alignment(x, below ? -1 : 1);
    _portal.show();
    if (_reduceMotion) {
      _open.value = 1;
    } else {
      _open.value = 0;
      _open.animateWith(SpringSimulation(MenuMetrics.open, 0, 1, 0));
    }
  }

  Future<void> _hide() async {
    if (!_portal.isShowing) return;
    if (!_reduceMotion) {
      await _open.animateTo(0, duration: MenuMetrics.close);
    }
    if (mounted) _portal.hide();
  }

  Future<void> _choose(GlassMenuItem item) async {
    await _hide();
    item.onSelected?.call();
  }

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: widget.mode,
    builder: (context, mode) =>
        mode == EffectiveGlassMode.material ? _material() : _glass(),
  );

  Widget _material() => MenuAnchor(
    menuChildren: [
      for (final item in widget.items)
        MenuItemButton(
          onPressed: item.onSelected,
          trailingIcon: item.icon == null ? null : Icon(item.icon),
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

  Widget _glass() => CompositedTransformTarget(
    link: _link,
    child: OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _menu,
      child: GlassButton.icon(
        onPressed: _show,
        icon: widget.icon,
        semanticLabel: widget.semanticLabel,
        mode: widget.mode,
      ),
    ),
  );

  Widget _menu(BuildContext context) => Stack(
    children: [
      // Tapping outside closes the menu without reaching the page.
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _hide,
          child: const ColoredBox(color: GlassColors.transparent),
        ),
      ),
      // Positioned, so the follower is the menu's size and its anchor is a
      // corner of the menu.
      Positioned(
        left: 0,
        top: 0,
        child: CompositedTransformFollower(
          link: _link,
          targetAnchor: _buttonAnchor,
          followerAnchor: _menuAnchor,
          offset: Offset(
            0,
            _menuAnchor.y < 0 ? MenuMetrics.gap : -MenuMetrics.gap,
          ),
          child: AnimatedBuilder(
            animation: _open,
            builder: (context, child) => Opacity(
              opacity: _open.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.3 + 0.7 * _open.value,
                alignment: _menuAnchor,
                child: child,
              ),
            ),
            child: SizedBox(
              width: MenuMetrics.width,
              child: Semantics(
                scopesRoute: true,
                explicitChildNodes: true,
                // Its own group: the overlay inherits the button's scopes,
                // and in a bar's group the menu would merge with the
                // buttons' capsule.
                child: GlassGroup(
                  mode: widget.mode,
                  child: LiquidGlass(
                    mode: widget.mode,
                    shape: const GlassShape.rect(MenuMetrics.cornerRadius),
                    padding: const EdgeInsets.symmetric(
                      vertical: MenuMetrics.verticalPadding,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final item in widget.items)
                          GlassMenuRow(
                            item: item,
                            onTap: item.onSelected == null
                                ? null
                                : () => _choose(item),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

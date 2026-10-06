import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../core/cupertino_l10n.dart';
import '../core/glass_colors.dart';
import '../core/glass_render_mode.dart';
import 'glass_menu_item.dart';
import 'glass_menu_panel.dart';
import 'glass_menu_placement.dart';
import 'menu_metrics.dart';

/// Opens a glass menu of [items] from whatever [builder] draws; the
/// builder gets the callback that opens it.
///
/// While the menu is open it takes the opener's place, as SwiftUI's does
/// (the opener leaves the tree: hiding native glass is not possible). A
/// tap outside closes it; choosing an item closes it, then runs the item.
class GlassMenuAnchor extends StatefulWidget {
  /// Creates the anchor.
  const GlassMenuAnchor({
    super.key,
    required this.items,
    required this.builder,
    this.placement = GlassMenuPlacement.corner,
    this.mode,
  });

  /// The menu's rows.
  final List<GlassMenuItem> items;

  /// Draws the opener; call the given callback to open the menu.
  final Widget Function(BuildContext context, VoidCallback open) builder;

  /// Where the menu opens.
  final GlassMenuPlacement placement;

  /// The rendering path.
  final GlassRenderMode? mode;

  @override
  State<GlassMenuAnchor> createState() => _GlassMenuAnchorState();
}

class _GlassMenuAnchorState extends State<GlassMenuAnchor>
    with SingleTickerProviderStateMixin {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  late final AnimationController _open = AnimationController.unbounded(
    vsync: this,
  );

  /// The opener's corner (or centre) the menu hangs from.
  Alignment _target = Alignment.topRight;

  /// The menu's matching point.
  Alignment _follower = Alignment.topRight;

  /// The opener's size, kept while the menu stands in for it.
  Size _openerSize = Size.zero;

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _show() {
    final box = context.findRenderObject()! as RenderBox;
    _openerSize = box.size;
    if (widget.placement == GlassMenuPlacement.centred) {
      _target = Alignment.center;
      _follower = Alignment.topCenter;
    } else {
      final centre = box.localToGlobal(box.size.center(Offset.zero));
      final screen = MediaQuery.sizeOf(context);
      final below = centre.dy < screen.height * 0.6;
      final x = centre.dx > screen.width / 2 ? 1.0 : -1.0;
      // The menu opens over the button, from the button's own corner.
      _target = _follower = Alignment(x, below ? -1 : 1);
    }
    setState(_portal.show);
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
    if (mounted) setState(_portal.hide);
  }

  Future<void> _choose(GlassMenuItem item) async {
    await _hide();
    item.onSelected?.call();
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _link,
    child: OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _menu,
      child: _portal.isShowing
          ? SizedBox.fromSize(size: _openerSize)
          : widget.builder(context, _show),
    ),
  );

  Widget _menu(BuildContext context) => Stack(
    children: [
      // Tapping outside closes the menu without reaching the page. For
      // assistive tech it is a labelled dismiss target, as a modal
      // barrier is.
      Positioned.fill(
        child: Semantics(
          label: cupertinoL10n(context).modalBarrierDismissLabel,
          onTap: _hide,
          onDismiss: _hide,
          child: GestureDetector(
            excludeFromSemantics: true,
            behavior: HitTestBehavior.opaque,
            onTap: _hide,
            child: const ColoredBox(color: GlassColors.transparent),
          ),
        ),
      ),
      // Positioned, so the follower is the menu's size.
      Positioned(
        left: 0,
        top: 0,
        child: CompositedTransformFollower(
          link: _link,
          targetAnchor: _target,
          followerAnchor: _follower,
          offset: widget.placement == GlassMenuPlacement.centred
              ? const Offset(0, -MenuMetrics.pickerOffset)
              : Offset.zero,
          child: AnimatedBuilder(
            animation: _open,
            builder: (context, child) => Opacity(
              opacity: _open.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.3 + 0.7 * _open.value,
                alignment: _follower,
                child: child,
              ),
            ),
            child: GlassMenuPanel(
              items: widget.items,
              mode: widget.mode,
              onChoose: _choose,
            ),
          ),
        ),
      ),
    ],
  );
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show ValueListenable;

import '../core/glass_colors.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_shape.dart';
import '../core/ios_text.dart';
import '../group/glass_group.dart';
import '../liquid_glass.dart';
import 'glass_menu_item.dart';
import 'glass_menu_row.dart';
import 'menu_metrics.dart';
import 'menu_sections.dart';

/// The glass panel of a menu: its rows on a [MenuMetrics.width] card, in
/// sections with dividers between them, and an open submenu's card over
/// the receded menu.
class GlassMenuPanel extends StatefulWidget {
  /// Creates the panel; [onChoose] runs when an action row is tapped.
  const GlassMenuPanel({
    super.key,
    required this.items,
    required this.onChoose,
    this.mode,
    this.highlighted,
  });

  /// The items, top to bottom.
  final List<GlassMenuItem> items;

  /// Called with the tapped action.
  final ValueChanged<GlassMenuItem> onChoose;

  /// The rendering path.
  final GlassRenderMode? mode;

  /// The row a glide highlights, an index into the rows that show (see
  /// [GlassMenuPanelState.rowAt]), if any; see [GlassMenuController].
  final ValueListenable<int?>? highlighted;

  @override
  State<GlassMenuPanel> createState() => GlassMenuPanelState();
}

/// The panel's state: the open submenu and the rows a finger can glide
/// over.
class GlassMenuPanelState extends State<GlassMenuPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _recede = AnimationController(
    vsync: this,
    duration: MenuMetrics.submenu,
  );

  /// The open submenu; kept while it closes.
  GlassMenuItem? _submenu;

  /// The submenu card's top in the panel.
  double _submenuTop = 0;

  /// The rows that respond to a finger, in order: the menu's, or the open
  /// submenu's (its own row first). Rebuilt with every build.
  final List<GlassMenuItem> _rows = [];
  final List<GlobalKey> _keys = [];

  /// Whether a submenu is open (or opening).
  bool get submenuOpen =>
      _submenu != null && _recede.status.isForwardOrCompleted;

  @override
  void didUpdateWidget(covariant GlassMenuPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_submenu != null && !_contains(widget.items, _submenu!)) {
      _submenu = null;
      _recede.value = 0;
    }
  }

  static bool _contains(List<GlassMenuItem> items, GlassMenuItem item) =>
      items.any(
        (i) =>
            identical(i, item) || (i.isSection && _contains(i.children, item)),
      );

  @override
  void dispose() {
    _recede.dispose();
    super.dispose();
  }

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// The row under [globalPosition] that a finger can choose, as an index
  /// for [GlassMenuPanel.highlighted]; null over padding, a title, a
  /// divider or a disabled row.
  int? rowAt(Offset globalPosition) {
    for (var i = 0; i < _keys.length; i++) {
      final box = _keys[i].currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final local = box.globalToLocal(globalPosition);
      if ((Offset.zero & box.size).contains(local)) {
        return _rows[i].enabled ? i : null;
      }
    }
    return null;
  }

  /// Activates row [index] as a tap on it does.
  void activateRow(int index) {
    if (index < 0 || index >= _rows.length) return;
    _tap(_rows[index], _keys[index]);
  }

  void _tap(GlassMenuItem item, GlobalKey key) {
    if (identical(item, _submenu)) return closeSubmenu();
    if (item.isSubmenu) return _openSubmenu(item, key);
    widget.onChoose(item);
  }

  void _openSubmenu(GlassMenuItem item, GlobalKey key) {
    final row = key.currentContext?.findRenderObject();
    final panel = context.findRenderObject();
    if (row is! RenderBox || panel is! RenderBox) return;
    // The menu recedes from its top: the submenu's own row lands on the
    // receded row.
    final y = row.localToGlobal(Offset.zero, ancestor: panel).dy;
    setState(() {
      _submenu = item;
      _submenuTop = y * MenuMetrics.recededScale - MenuMetrics.verticalPadding;
    });
    if (_reduceMotion) {
      _recede.value = 1;
    } else {
      _recede.forward();
    }
  }

  /// Closes the open submenu, back to the menu.
  void closeSubmenu() {
    if (_submenu == null) return;
    void done() {
      if (mounted) setState(() => _submenu = null);
    }

    if (_reduceMotion) {
      _recede.value = 0;
      done();
    } else {
      _recede.reverse().then((_) {
        if (_recede.value == 0) done();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final submenu = _submenu;
    final menu = GlassGroup(
      mode: widget.mode,
      child: LiquidGlass(
        mode: widget.mode,
        shape: const GlassShape.rect(MenuMetrics.cornerRadius),
        padding: const EdgeInsets.symmetric(
          vertical: MenuMetrics.verticalPadding,
        ),
        child: _highlightable(
          (h) => _sections(
            widget.items,
            interactive: submenu == null,
            highlight: h,
          ),
          enabled: submenu == null,
        ),
      ),
    );
    return SizedBox(
      width: MenuMetrics.width,
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        // Its own group: an overlay inherits its opener's scopes, and in a
        // bar's group the menu would merge with the buttons' capsule.
        child: submenu == null
            ? menu
            : Stack(
                children: [
                  AnimatedBuilder(
                    animation: _recede,
                    builder: (context, child) {
                      final t = Curves.easeOut.transform(_recede.value);
                      return Transform.scale(
                        scale: 1 - (1 - MenuMetrics.recededScale) * t,
                        alignment: AlignmentDirectional.topEnd.resolve(
                          Directionality.of(context),
                        ),
                        child: Opacity(
                          opacity: 1 - (1 - MenuMetrics.recededOpacity) * t,
                          child: child,
                        ),
                      );
                    },
                    child: ExcludeSemantics(child: IgnorePointer(child: menu)),
                  ),
                  // A tap on the receded menu goes back to it.
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      onTap: closeSubmenu,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      top: _submenuTop.clamp(0, double.infinity),
                    ),
                    child: _card(submenu),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _highlightable(
    Widget Function(int? highlight) build, {
    required bool enabled,
  }) {
    if (!enabled) return build(null);
    // The rows that show are indexed afresh with each build of them.
    Widget indexed(int? value) {
      _rows.clear();
      return build(value);
    }

    final listenable = widget.highlighted;
    if (listenable == null) return indexed(null);
    return ValueListenableBuilder<int?>(
      valueListenable: listenable,
      builder: (context, value, _) => indexed(value),
    );
  }

  Widget _card(GlassMenuItem submenu) => AnimatedBuilder(
    animation: _recede,
    builder: (context, child) {
      final t = Curves.easeOut.transform(_recede.value);
      return Opacity(
        opacity: t,
        child: Transform.scale(
          scale: 0.9 + 0.1 * t,
          alignment: Alignment.topCenter,
          child: child,
        ),
      );
    },
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(
          GlassColors.menuSubmenuCard,
          context,
        ),
        borderRadius: BorderRadius.circular(MenuMetrics.cornerRadius),
        boxShadow: const [
          BoxShadow(
            color: GlassColors.menuSubmenuShadow,
            blurRadius: 30,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: MenuMetrics.verticalPadding,
        ),
        child: _highlightable(
          (h) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row(
                submenu,
                icons: submenu.icon != null,
                highlight: h,
                trailing: CupertinoIcons.chevron_down,
                weight: FontWeight.w600,
              ),
              _divider(context),
              _sections(submenu.children, interactive: true, highlight: h),
            ],
          ),
          enabled: true,
        ),
      ),
    ),
  );

  Widget _sections(
    List<GlassMenuItem> items, {
    required bool interactive,
    int? highlight,
  }) {
    final choices = items.any(
      (i) =>
          i.checked != null ||
          (i.isSection && i.children.any((c) => c.checked != null)),
    );
    final sections = menuSections(items);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var s = 0; s < sections.length; s++) ...[
          if (s > 0) _divider(context),
          if (sections[s].title case final title?) _header(context, title),
          for (final item in sections[s].rows)
            _row(
              item,
              choices: choices,
              icons: sections[s].rows.any((r) => r.icon != null),
              highlight: interactive ? highlight : null,
              interactive: interactive,
              trailing: item.isSubmenu ? CupertinoIcons.chevron_forward : null,
            ),
        ],
      ],
    );
  }

  Widget _row(
    GlassMenuItem item, {
    bool choices = false,
    required bool icons,
    int? highlight,
    bool interactive = true,
    IconData? trailing,
    FontWeight weight = FontWeight.w400,
  }) {
    if (!interactive) {
      return GlassMenuRow(
        item: item,
        onTap: null,
        choices: choices,
        icons: icons,
        trailing: trailing,
        weight: weight,
      );
    }
    final index = _rows.length;
    _rows.add(item);
    if (_keys.length <= index) _keys.add(GlobalKey());
    final key = _keys[index];
    return GlassMenuRow(
      key: key,
      item: item,
      choices: choices,
      icons: icons,
      highlighted: highlight == index,
      trailing: trailing,
      weight: weight,
      onTap: item.enabled ? () => _tap(item, key) : null,
    );
  }
}

Widget _divider(BuildContext context) => Padding(
  padding: const EdgeInsetsDirectional.only(
    start: MenuMetrics.dividerStart,
    end: MenuMetrics.dividerEnd,
    top: MenuMetrics.verticalPadding,
    bottom: MenuMetrics.verticalPadding,
  ),
  child: SizedBox(
    height: MenuMetrics.dividerThickness,
    child: ColoredBox(
      color: CupertinoDynamicColor.resolve(GlassColors.menuSeparator, context),
    ),
  ),
);

Widget _header(BuildContext context, String title) {
  final scale =
      MediaQuery.textScalerOf(context).scale(MenuMetrics.headerFontSize) /
      MenuMetrics.headerFontSize;
  return ConstrainedBox(
    constraints: BoxConstraints(minHeight: MenuMetrics.headerHeight * scale),
    child: Padding(
      padding: const EdgeInsetsDirectional.only(
        start: MenuMetrics.headerStart,
        end: MenuMetrics.trailingPadding,
      ),
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: Baseline(
          baseline: MenuMetrics.headerBaseline * scale,
          baselineType: TextBaseline.alphabetic,
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: IOSText.style(
                MenuMetrics.headerFontSize,
                color: CupertinoDynamicColor.resolve(
                  GlassColors.secondaryLabel,
                  context,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

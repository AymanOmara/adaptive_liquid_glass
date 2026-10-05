import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        Badge,
        NavigationBar,
        NavigationDestination,
        Theme,
        WidgetState,
        WidgetStateProperty;
import 'package:flutter/physics.dart';

import '../core/glass.dart';
import '../core/glass_environment.dart';
import '../core/glass_render_mode.dart';
import '../core/render_mode_resolver.dart';
import '../core/swiftui_spring.dart';
import '../core/theme.dart';
import '../group/glass_group.dart';
import '../liquid_glass.dart';
import '../platform/glass_platform.dart';

/// One tab of a [GlassTabBar]: an icon over a short label.
@immutable
class GlassTabBarItem {
  /// Creates a tab.
  const GlassTabBarItem({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.badge,
  });

  /// The tab's icon.
  final IconData icon;

  /// The tab's label, also its accessibility label.
  final String label;

  /// The icon while this tab is selected; defaults to [icon].
  final IconData? activeIcon;

  /// A badge on the icon: a count or short text, or a dot when empty.
  /// Null shows none.
  final String? badge;
}

/// iOS 26's floating tab bar: a glass capsule with the selected tab on a
/// pill.
///
/// Pressing turns the pill into a clear glass lens that overhangs the bar
/// and magnifies the tabs under it in [selectedColor]; dragging slides the
/// lens between tabs; letting go springs it to the nearest tab, shrinks it
/// back into the pill and calls [onSelected]. A tap is a short press.
///
/// ```dart
/// GlassTabBar(
///   items: const [
///     GlassTabBarItem(icon: CupertinoIcons.clock_fill, label: 'History'),
///     GlassTabBarItem(icon: CupertinoIcons.gear_solid, label: 'Settings'),
///   ],
///   selectedIndex: tab,
///   onSelected: (i) => setState(() => tab = i),
/// )
/// ```
///
/// Float it over the content (for example at the bottom of a `Stack`) and
/// leave room under the content for it, as iOS does. Tabs are [itemWidth]
/// wide, narrower when the bar would not fit the width it is given.
/// Unselected tabs take the readable colour glass gives text and icons.
/// Follows the reading direction; with Reduce Motion the lens and pill move
/// without animating.
///
/// On the Material path (Android by default) it is a Material 3
/// [NavigationBar] in the same floating capsule.
class GlassTabBar extends StatefulWidget {
  /// Creates a glass tab bar.
  const GlassTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.selectedColor,
    this.indicatorColor,
    this.glass,
    this.mode,
    this.itemWidth = 88,
    this.height = 62,
  }) : assert(items.length >= 2, 'A tab bar needs at least two tabs.');

  /// The tabs, in reading order.
  final List<GlassTabBarItem> items;

  /// The index of the selected tab.
  final int selectedIndex;

  /// Called with the index of the tab the user picked; the bar shows
  /// [selectedIndex] until the parent rebuilds it with the new one.
  final ValueChanged<int> onSelected;

  /// The selected tab's icon and label, and the tabs under the lens.
  /// Defaults to `CupertinoTheme.primaryColor` (system blue), or Material
  /// 3's colours on the Material path.
  final Color? selectedColor;

  /// The pill behind the selected tab at rest. Defaults to the system's
  /// tertiary fill, or Material 3's indicator on the Material path.
  final Color? indicatorColor;

  /// The bar's glass. Defaults to the theme's default glass.
  final Glass? glass;

  /// The rendering path for the bar and its lens; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// The widest a tab gets, which is also the pill's width. Tabs shrink
  /// evenly when the bar would not fit the width it is given.
  final double itemWidth;

  /// The bar's height.
  final double height;

  @override
  State<GlassTabBar> createState() => _GlassTabBarState();
}

/// Measured from iOS 26.4's tab bar (Kept, iPhone 17 Pro).
abstract final class _Metrics {
  static const double inset = 4;

  /// How much wider than a tab the held lens is (108 over 88).
  static const double lensGrow = 20;
  static const double lensOverhang = 8;
  static const double growX = 8;
  static const double growY = 3;
  static const double magnify = 1.15;
  static const double iconSize = 26;
  static const double labelGap = 2;
  static const TextStyle label = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );
  static const double badgeHeight = 18;
  static const double badgeDot = 10;
  static const TextStyle badge = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1,
  );
  static const Duration grow = Duration(milliseconds: 180);
  static const Duration settle = Duration(milliseconds: 380);
  static final SpringDescription slide = swiftUISpring(
    response: 0.3,
    dampingFraction: 0.78,
  );
}

class _GlassTabBarState extends State<GlassTabBar>
    with TickerProviderStateMixin {
  /// The selection's centre, in tab widths from the row's left edge (the
  /// centre of the leftmost tab is 0.5), so a width change keeps it put.
  late final AnimationController _x = AnimationController.unbounded(
    vsync: this,
  );

  /// 0 at rest (the pill), 1 while held (the lens).
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: _Metrics.grow,
    reverseDuration: _Metrics.settle,
  );

  bool _placed = false;
  bool _held = false;

  /// Where the finger is, in tab widths; the lens may still be springing
  /// towards it.
  double _finger = 0;

  /// The width of one tab as last laid out.
  late double _itemWidth = widget.itemWidth;

  int get _count => widget.items.length;

  double get _contentHeight => widget.height - _Metrics.inset * 2;

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  /// Visual slot (left to right) of tab [index].
  int _slot(int index) => _rtl ? _count - 1 - index : index;

  double _centerOf(int index) => _slot(index) + 0.5;

  /// [dx] (pixels from the bar's left edge) in tab widths, kept on a tab.
  double _toSlots(double dx) =>
      ((dx - _Metrics.inset) / _itemWidth).clamp(0.5, _count - 0.5);

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _springTo(double target, {double velocity = 0}) {
    if (_reduceMotion) {
      _x.value = target;
    } else {
      _x.animateWith(
        SpringSimulation(_Metrics.slide, _x.value, target, velocity),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Needs the reading direction, so not in initState; a direction change
    // re-places the pill too.
    if (!_placed || !_held) _x.value = _centerOf(widget.selectedIndex);
    _placed = true;
  }

  @override
  void didUpdateWidget(GlassTabBar old) {
    super.didUpdateWidget(old);
    if (_held) return;
    if (old.selectedIndex != widget.selectedIndex) {
      _springTo(_centerOf(widget.selectedIndex));
    } else if (old.items.length != widget.items.length) {
      _x.value = _centerOf(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _x.dispose();
    _press.dispose();
    super.dispose();
  }

  void _down(DragDownDetails details) {
    _held = true;
    _finger = _toSlots(details.localPosition.dx);
    _reduceMotion ? _press.value = 1 : _press.forward();
    _springTo(_finger);
  }

  void _drag(DragUpdateDetails details) {
    _finger = _toSlots(details.localPosition.dx);
    _x.stop();
    _x.value = _finger;
  }

  void _release(double velocity) {
    _held = false;
    final slot = _finger.floor().clamp(0, _count - 1);
    final index = _rtl ? _count - 1 - slot : slot;
    _springTo(_centerOf(index), velocity: velocity / _itemWidth);
    _reduceMotion ? _press.value = 0 : _press.reverse();
    if (index != widget.selectedIndex) widget.onSelected(index);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final fit = (constraints.maxWidth - _Metrics.inset * 2) / _count;
      _itemWidth = fit < widget.itemWidth ? fit : widget.itemWidth;
      return ValueListenableBuilder<GlassEnvironment>(
        valueListenable: GlassPlatform.instance.environment,
        builder: (context, environment, _) {
          final mode = resolveGlassMode(
            requested: widget.mode ?? LiquidGlassTheme.of(context).defaultMode,
            environment: environment,
          );
          return mode == EffectiveGlassMode.material
              ? _materialBar(context)
              : _glassBar(context);
        },
      );
    },
  );

  /// Material 3's navigation bar, floating in the same capsule.
  Widget _materialBar(BuildContext context) {
    final selected = widget.selectedColor;
    final label = Theme.of(context).textTheme.labelMedium;
    return SizedBox(
      width: _rowWidth + _Metrics.inset * 2,
      child: ClipPath(
        clipper: const ShapeBorderClipper(shape: StadiumBorder()),
        // Floating above the bottom edge, so no safe-area padding.
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: NavigationBar(
            height: widget.height,
            selectedIndex: widget.selectedIndex,
            onDestinationSelected: widget.onSelected,
            indicatorColor: widget.indicatorColor,
            labelTextStyle: selected == null
                ? null
                : WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? label?.copyWith(color: selected) ??
                              TextStyle(color: selected)
                        : null,
                  ),
            destinations: [
              for (final item in widget.items)
                NavigationDestination(
                  icon: _materialBadge(item, Icon(item.icon)),
                  selectedIcon: _materialBadge(
                    item,
                    Icon(item.activeIcon ?? item.icon, color: selected),
                  ),
                  label: item.label,
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _materialBadge(GlassTabBarItem item, Widget icon) =>
      switch (item.badge) {
        null => icon,
        '' => Badge(child: icon),
        final text => Badge(label: Text(text), child: icon),
      };

  double get _rowWidth => _count * _itemWidth;

  Widget _glassBar(BuildContext context) {
    final selected = CupertinoDynamicColor.resolve(
      widget.selectedColor ?? CupertinoTheme.of(context).primaryColor,
      context,
    );
    final indicator = CupertinoDynamicColor.resolve(
      widget.indicatorColor ?? CupertinoColors.tertiarySystemFill,
      context,
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onPanDown: _down,
        onPanUpdate: _drag,
        onPanEnd: (d) => _release(d.velocity.pixelsPerSecond.dx),
        onPanCancel: () => _release(0),
        child: AnimatedBuilder(
          animation: Listenable.merge([_x, _press]),
          builder: (context, _) => _bar(
            Curves.easeOutCubic.transform(_press.value),
            selected,
            indicator,
          ),
        ),
      ),
    );
  }

  Widget _bar(double t, Color selected, Color indicator) {
    final itemWidth = _itemWidth;
    final x = _x.value * itemWidth;
    final lens = Rect.fromCenter(
      center: Offset(x, _contentHeight / 2),
      width: itemWidth + _Metrics.lensGrow * t,
      height: _contentHeight + _Metrics.lensOverhang * 2 * t,
    );
    final growX = _Metrics.growX * t;
    final growY = _Metrics.growY * t;
    return SizedBox(
      width: _rowWidth + _Metrics.inset * 2,
      height: widget.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -growX,
            right: -growX,
            top: -growY,
            bottom: -growY,
            child: GlassGroup(
              mode: widget.mode,
              child: LiquidGlass(
                glass: widget.glass,
                mode: widget.mode,
                child: Center(
                  child: SizedBox(
                    width: _rowWidth,
                    height: _contentHeight,
                    child: Stack(
                      children: [
                        Positioned(
                          left: x - itemWidth / 2,
                          width: itemWidth,
                          top: 0,
                          bottom: 0,
                          child: Opacity(
                            opacity: 1 - t,
                            child: DecoratedBox(
                              decoration: ShapeDecoration(
                                shape: const StadiumBorder(),
                                color: indicator,
                              ),
                            ),
                          ),
                        ),
                        // Under a held lens the row has a hole: the lens
                        // shows its own magnified, tinted copy instead.
                        ClipPath(
                          clipper: _Hole(t > 0 ? lens : null),
                          child: _row(
                            (i) => t == 0 && i == widget.selectedIndex
                                ? selected
                                : null,
                            semantics: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (t > 0)
            Positioned.fromRect(
              rect: lens.shift(const Offset(_Metrics.inset, _Metrics.inset)),
              child: GlassGroup(
                mode: widget.mode,
                child: LiquidGlass(
                  glass: Glass.clear,
                  mode: widget.mode,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(lens.height / 2),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: -lens.left,
                          top: -lens.top,
                          width: _rowWidth,
                          height: _contentHeight,
                          child: Transform.scale(
                            scale: lerpDouble(1, _Metrics.magnify, t),
                            origin: Offset(x - _rowWidth / 2, 0),
                            child: _row((_) => selected, semantics: false),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The tabs; [colorOf] null leaves a tab to the glass's readable colour.
  Widget _row(Color? Function(int index) colorOf, {required bool semantics}) {
    final row = Row(
      children: [
        for (var i = 0; i < _count; i++)
          Semantics(
            button: true,
            inMutuallyExclusiveGroup: true,
            selected: i == widget.selectedIndex,
            label: widget.items[i].label,
            value: widget.items[i].badge,
            onTap: () => widget.onSelected(i),
            child: ExcludeSemantics(
              child: SizedBox(
                width: _itemWidth,
                height: _contentHeight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _icon(
                      widget.items[i],
                      i == widget.selectedIndex,
                      colorOf(i),
                    ),
                    const SizedBox(height: _Metrics.labelGap),
                    Text(
                      widget.items[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: _Metrics.label.copyWith(color: colorOf(i)),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
    return semantics ? row : ExcludeSemantics(child: row);
  }

  /// The tab's icon, with its badge at the top trailing corner.
  Widget _icon(GlassTabBarItem item, bool isSelected, Color? color) {
    final icon = Icon(
      isSelected ? item.activeIcon ?? item.icon : item.icon,
      size: _Metrics.iconSize,
      color: color,
    );
    final badge = item.badge;
    if (badge == null) return icon;
    final dot = badge.isEmpty;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        PositionedDirectional(
          start: _Metrics.iconSize * (dot ? 0.7 : 0.55),
          top: dot ? -1 : -6,
          child: Container(
            height: dot ? _Metrics.badgeDot : _Metrics.badgeHeight,
            constraints: BoxConstraints(
              minWidth: dot ? _Metrics.badgeDot : _Metrics.badgeHeight,
            ),
            padding: dot
                ? null
                : const EdgeInsetsDirectional.symmetric(horizontal: 5),
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.systemRed,
                context,
              ),
            ),
            child: dot
                ? null
                : Text(
                    badge,
                    maxLines: 1,
                    style: _Metrics.badge.copyWith(
                      color: const Color(0xFFFFFFFF),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Everything but [hole] (a capsule); everything when it is null.
class _Hole extends CustomClipper<Path> {
  const _Hole(this.hole);

  final Rect? hole;

  @override
  Path getClip(Size size) {
    final all = Path()..addRect(Offset.zero & size);
    final hole = this.hole;
    if (hole == null) return all;
    return Path.combine(
      PathOperation.difference,
      all,
      Path()..addRRect(
        RRect.fromRectAndRadius(hole, Radius.circular(hole.height / 2)),
      ),
    );
  }

  @override
  bool shouldReclip(_Hole old) => old.hole != hole;
}

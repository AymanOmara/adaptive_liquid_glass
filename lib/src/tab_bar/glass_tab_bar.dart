import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';

import '../core/glass.dart';
import '../core/glass_render_mode.dart';
import '../core/swiftui_spring.dart';
import '../group/glass_group.dart';
import '../liquid_glass.dart';

/// One tab of a [GlassTabBar]: an icon over a short label.
@immutable
class GlassTabBarItem {
  /// Creates a tab.
  const GlassTabBarItem({required this.icon, required this.label});

  /// The tab's icon.
  final IconData icon;

  /// The tab's label, also its accessibility label.
  final String label;
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
/// leave room under the content for it, as iOS does. Unselected tabs take
/// the readable colour glass gives text and icons. Follows the reading
/// direction; with Reduce Motion the lens and pill move without animating.
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
  /// Defaults to `CupertinoTheme.primaryColor` (system blue).
  final Color? selectedColor;

  /// The pill behind the selected tab at rest. Defaults to the system's
  /// tertiary fill.
  final Color? indicatorColor;

  /// The bar's glass. Defaults to the theme's default glass.
  final Glass? glass;

  /// The rendering path for the bar and its lens; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// The width of one tab, which is also the pill's width.
  final double itemWidth;

  /// The bar's height.
  final double height;

  @override
  State<GlassTabBar> createState() => _GlassTabBarState();
}

/// Measured from iOS 26.4's tab bar (Kept, iPhone 17 Pro).
abstract final class _Metrics {
  static const double inset = 4;
  static const double lensWidth = 108;
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
  static const Duration grow = Duration(milliseconds: 180);
  static const Duration settle = Duration(milliseconds: 380);
  static final SpringDescription slide = swiftUISpring(
    response: 0.3,
    dampingFraction: 0.78,
  );
}

class _GlassTabBarState extends State<GlassTabBar>
    with TickerProviderStateMixin {
  /// The selection's centre, in the tab row's coordinates (left to right).
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

  /// Where the finger is, which the lens may still be springing towards.
  double _finger = 0;

  int get _count => widget.items.length;

  double get _rowWidth => _count * widget.itemWidth;

  double get _contentHeight => widget.height - _Metrics.inset * 2;

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  /// Visual slot (left to right) of tab [index], and back.
  int _slot(int index) => _rtl ? _count - 1 - index : index;

  double _centerOf(int index) => widget.itemWidth * (_slot(index) + 0.5);

  double _clamp(double x) => x
      .clamp(widget.itemWidth / 2, _rowWidth - widget.itemWidth / 2)
      .toDouble();

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
    } else if (old.itemWidth != widget.itemWidth ||
        old.items.length != widget.items.length) {
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
    _finger = _clamp(details.localPosition.dx - _Metrics.inset);
    _reduceMotion ? _press.value = 1 : _press.forward();
    _springTo(_finger);
  }

  void _drag(DragUpdateDetails details) {
    _finger = _clamp(details.localPosition.dx - _Metrics.inset);
    _x.stop();
    _x.value = _finger;
  }

  void _release(double velocity) {
    _held = false;
    final slot = (_finger / widget.itemWidth).floor().clamp(0, _count - 1);
    final index = _rtl ? _count - 1 - slot : slot;
    _springTo(_centerOf(index), velocity: velocity);
    _reduceMotion ? _press.value = 0 : _press.reverse();
    if (index != widget.selectedIndex) widget.onSelected(index);
  }

  @override
  Widget build(BuildContext context) {
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
    final itemWidth = widget.itemWidth;
    final lens = Rect.fromCenter(
      center: Offset(_x.value, _contentHeight / 2),
      width: lerpDouble(itemWidth, _Metrics.lensWidth, t)!,
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
                          left: _x.value - itemWidth / 2,
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
                            origin: Offset(_x.value - _rowWidth / 2, 0),
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
            onTap: () => widget.onSelected(i),
            child: ExcludeSemantics(
              child: SizedBox(
                width: widget.itemWidth,
                height: _contentHeight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.items[i].icon,
                      size: _Metrics.iconSize,
                      color: colorOf(i),
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

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
import 'package:flutter/scheduler.dart' show Ticker;

import '../core/glass.dart';
import '../core/glass_environment.dart';
import '../core/glass_render_mode.dart';
import '../core/render_mode_resolver.dart';
import '../core/swiftui_spring.dart';
import '../core/theme.dart';
import '../group/glass_group.dart';
import '../liquid_glass.dart';
import '../platform/glass_platform.dart';
import 'tab_lens.dart';

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
    this.itemWidth = 86.15,
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
  /// secondary fill (as iOS 26.4 draws it), or Material 3's indicator on
  /// the Material path.
  final Color? indicatorColor;

  /// The bar's glass. Defaults to the theme's default glass.
  final Glass? glass;

  /// The rendering path for the bar and its lens; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// The distance between neighbouring tabs at most (the selection pill is
  /// 7.55 wider, as on iOS). Tabs move closer evenly when the bar would not
  /// fit the width it is given.
  final double itemWidth;

  /// The bar's height.
  final double height;

  @override
  State<GlassTabBar> createState() => _GlassTabBarState();
}

/// Measured from iOS 26.4's tab bar (Kept, iPhone 17 Pro) by frame-by-frame
/// tracking of press, hold, drag and release (`example/lib/tab_bar_probe.dart`
/// lays the bar out the same way).
abstract final class _Metrics {
  static const double inset = 4;

  /// How much wider than the tab spacing the pill is (93.7 over 86.15).
  static const double pillExtra = 7.55;

  /// The held lens over the pill: 114.3 by 74 against 93.7 by 54.
  static const double lensGrowX = 20.6;
  static const double lensGrowY = 20;

  /// The lens sits 1.06 times as far from the bar's centre as the finger,
  /// up to this far past the outermost tab.
  static const double lensGain = 1.06;
  static const double lensReach = 7.1;

  /// While held the bar grows this much on each side, plus [growLean] of
  /// the lens's offset from the centre towards the lens.
  static const double growX = 9.15;
  static const double growY = 1.65;
  static const double growLean = 0.0237;

  /// Tabs under the lens are magnified more across than down.
  static const double magnifyX = 1.21;
  static const double magnifyY = 1.10;

  /// The band at the lens's edge where content is refracted, not sharp.
  static const double lensRim = 9;

  /// The lens's height wobbles with its sideways acceleration (taller when
  /// it accelerates to the left), as a damped oscillator: points of extra
  /// overhang per side per pt/s² of acceleration.
  static const double wobbleGain = 0.002607;
  static final SpringDescription wobble = swiftUISpring(
    response: 1.159,
    dampingFraction: 0.499,
  );

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

  /// Pill to lens, lens back to pill (it undershoots: the pill squashes).
  static final SpringDescription press = swiftUISpring(
    response: 0.381,
    dampingFraction: 0.752,
  );
  static final SpringDescription release = swiftUISpring(
    response: 0.27,
    dampingFraction: 0.55,
  );

  /// The lens following the finger.
  static final SpringDescription follow = swiftUISpring(
    response: 0.3,
    dampingFraction: 0.8,
  );

  /// The pill moving to a newly selected tab.
  static final SpringDescription slide = swiftUISpring(
    response: 0.3,
    dampingFraction: 0.78,
  );
}

class _GlassTabBarState extends State<GlassTabBar>
    with TickerProviderStateMixin {
  /// The selection's centre in visual slots, left to right (the leftmost
  /// tab's centre is 0), so a width change keeps it put.
  late final AnimationController _x = AnimationController.unbounded(
    vsync: this,
  );

  /// 0 at rest (the pill), 1 while held (the lens); springs past both.
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );

  /// Extra lens overhang per side from the sideways wobble, in points.
  final ValueNotifier<double> _wobble = ValueNotifier(0);
  late final Ticker _wobbleTicker = createTicker(_stepWobble);
  double _wobbleVelocity = 0;
  double _lastVelocity = 0;
  Duration _lastTick = Duration.zero;

  /// Whether the lens is drawn with the package's shader (fitted to iOS's
  /// tab lens); without shader support it is the requested glass.
  bool _shaderLens = false;

  /// The bar's path: with the shader lens the bar is shader glass too, so
  /// the lens can refract it (native glass is invisible to the shader). An
  /// explicit [GlassTabBar.mode] wins.
  GlassRenderMode? get _barMode =>
      widget.mode ?? (_shaderLens ? GlassRenderMode.shader : null);

  bool _placed = false;
  bool _held = false;

  /// Where the finger is, in visual slots.
  double _finger = 0;

  /// The spacing of the tabs as last laid out.
  late double _itemWidth = widget.itemWidth;

  int get _count => widget.items.length;

  double get _pillWidth => _itemWidth + _Metrics.pillExtra;

  double get _rowWidth => _pillWidth + (_count - 1) * _itemWidth;

  double get _contentHeight => widget.height - _Metrics.inset * 2;

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  /// Visual slot (left to right) of tab [index].
  int _slot(int index) => _rtl ? _count - 1 - index : index;

  double get _middle => (_count - 1) / 2;

  /// [dx] (pixels from the bar's left edge) in visual slots.
  double _toSlots(double dx) =>
      (dx - _Metrics.inset - _pillWidth / 2) / _itemWidth;

  /// Where the lens heads for a finger at [finger] (visual slots).
  double _lensTarget(double finger) {
    final reach = _Metrics.lensGain * _middle + _Metrics.lensReach / _itemWidth;
    return _middle +
        (_Metrics.lensGain * (finger - _middle)).clamp(-reach, reach);
  }

  /// Pixels from the row's left edge of visual slot position [slots].
  double _toPixels(double slots) => _pillWidth / 2 + slots * _itemWidth;

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _springX(SpringDescription spring, double target) {
    if (_reduceMotion) {
      _x.value = target;
    } else {
      _x.animateWith(SpringSimulation(spring, _x.value, target, _x.velocity));
    }
  }

  void _springPress(SpringDescription spring, double target) {
    if (_reduceMotion) {
      _press.value = target;
    } else {
      _press
          .animateWith(
            SpringSimulation(spring, _press.value, target, _press.velocity),
          )
          .whenCompleteOrCancel(() {
            // A spring stops within its tolerance, not on the target; a
            // lens left a hair above zero would keep drawing (blurred and
            // refracted) over the pill.
            if (!_held && target == 0 && mounted) _press.value = 0;
          });
    }
  }

  /// Integrates the wobble from the lens's acceleration each frame.
  void _stepWobble(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0 || dt > 0.1) {
      _lastVelocity = _x.velocity;
      return;
    }
    final velocity = _x.isAnimating ? _x.velocity : 0.0;
    final acceleration = (velocity - _lastVelocity) / dt * _itemWidth;
    _lastVelocity = velocity;
    final spring = _Metrics.wobble;
    final k = spring.stiffness / spring.mass;
    final c = spring.damping / spring.mass;
    // Semi-implicit Euler in small steps for stability.
    const steps = 4;
    final h = dt / steps;
    var y = _wobble.value;
    for (var i = 0; i < steps; i++) {
      final a =
          -k * y - c * _wobbleVelocity - k * _Metrics.wobbleGain * acceleration;
      _wobbleVelocity += a * h;
      y += _wobbleVelocity * h;
    }
    _wobble.value = y;
    if (!_held &&
        !_x.isAnimating &&
        y.abs() < 0.01 &&
        _wobbleVelocity.abs() < 0.01) {
      _wobble.value = 0;
      _wobbleVelocity = 0;
      _wobbleTicker.stop();
    }
  }

  void _startWobble() {
    if (_reduceMotion || _wobbleTicker.isActive) return;
    _lastTick = Duration.zero;
    _lastVelocity = _x.velocity;
    _wobbleTicker.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Needs the reading direction, so not in initState; a direction change
    // re-places the pill too.
    if (!_placed || !_held) _x.value = _slot(widget.selectedIndex).toDouble();
    _placed = true;
  }

  @override
  void didUpdateWidget(GlassTabBar old) {
    super.didUpdateWidget(old);
    if (_held) return;
    if (old.selectedIndex != widget.selectedIndex) {
      _springX(_Metrics.slide, _slot(widget.selectedIndex).toDouble());
    } else if (old.items.length != widget.items.length) {
      _x.value = _slot(widget.selectedIndex).toDouble();
    }
  }

  @override
  void dispose() {
    _wobbleTicker.dispose();
    _wobble.dispose();
    _x.dispose();
    _press.dispose();
    super.dispose();
  }

  void _down(DragDownDetails details) {
    _held = true;
    _finger = _toSlots(details.localPosition.dx);
    _springPress(_Metrics.press, 1);
    // The lens grows where the finger lands (as iOS does), not from the
    // old selection.
    _x.value = _lensTarget(_finger);
    _startWobble();
  }

  void _drag(DragUpdateDetails details) {
    _finger = _toSlots(details.localPosition.dx);
    _springX(_Metrics.follow, _lensTarget(_finger));
  }

  void _release(double velocity) {
    _held = false;
    final slot = _finger.round().clamp(0, _count - 1);
    final index = _rtl ? _count - 1 - slot : slot;
    _springX(_Metrics.slide, slot.toDouble());
    _springPress(_Metrics.release, 0);
    if (index != widget.selectedIndex) widget.onSelected(index);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final fit =
          (constraints.maxWidth - _Metrics.inset * 2 - _Metrics.pillExtra) /
          _count;
      _itemWidth = fit < widget.itemWidth ? fit : widget.itemWidth;
      return ValueListenableBuilder<GlassEnvironment>(
        valueListenable: GlassPlatform.instance.environment,
        builder: (context, environment, _) {
          _shaderLens = environment.shaderSupported;
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

  Widget _glassBar(BuildContext context) {
    final selected = CupertinoDynamicColor.resolve(
      widget.selectedColor ?? CupertinoTheme.of(context).primaryColor,
      context,
    );
    final indicator = CupertinoDynamicColor.resolve(
      widget.indicatorColor ?? CupertinoColors.secondarySystemFill,
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
          animation: Listenable.merge([_x, _press, _wobble]),
          builder: (context, _) => _bar(_press.value, selected, indicator),
        ),
      ),
    );
  }

  Widget _bar(double p, Color selected, Color indicator) {
    // p springs past 0 and 1; the lens shows only while it is above 0,
    // but the pill and lens sizes follow p itself (the pill squashes).
    final t = p.clamp(0.0, 1.0);
    // Only a lens that is held or still visibly grown is drawn: a release
    // spring rebounds a hair above zero, and a hair-thin lens would still
    // refract a ghost of the tabs over the pill.
    // (The release spring's second rebound peaks near 0.016.)
    final lensShown = _held || p > 0.05;
    final x = _toPixels(_x.value);
    // The wobble belongs to the held lens: it fades with it and never
    // reaches the pill.
    final wobble = _wobble.value * t;
    final lens = Rect.fromCenter(
      center: Offset(x, _contentHeight / 2),
      width: _pillWidth + _Metrics.lensGrowX * p,
      height: _contentHeight + _Metrics.lensGrowY * p + wobble * 2,
    );
    final lean = _Metrics.growLean * (x - _rowWidth / 2) * t;
    final growX = _Metrics.growX * t;
    final growY = _Metrics.growY * t;
    return SizedBox(
      width: _rowWidth + _Metrics.inset * 2,
      height: widget.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -growX + lean,
            right: -growX - lean,
            top: -growY,
            bottom: -growY,
            child: GlassGroup(
              mode: _barMode,
              child: LiquidGlass(
                glass: widget.glass,
                mode: _barMode,
                child: Center(
                  child: SizedBox(
                    width: _rowWidth,
                    height: _contentHeight,
                    child: Stack(
                      children: [
                        Positioned.fromRect(
                          rect: p < 0
                              ? lens
                              : Rect.fromCenter(
                                  center: lens.center,
                                  width: _pillWidth,
                                  height: _contentHeight,
                                ),
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
                        // Under a held lens the row has a hole filled by a
                        // magnified, tinted copy. Both lie beneath the
                        // lens, so its glass refracts them (bending them at
                        // its rim, as iOS does).
                        ClipPath(
                          clipper: _Hole(lensShown ? lens : null),
                          child: _row(
                            // Gated like the lens, not on p == 0: the
                            // settling spring crosses zero several times and
                            // would flicker the tint off and on.
                            (i) => !lensShown && i == widget.selectedIndex
                                ? selected
                                : null,
                            semantics: true,
                          ),
                        ),
                        if (lensShown)
                          ClipPath(
                            // The shader lens bends the whole copy; native
                            // glass only gets the ends (see _LensEnds).
                            clipper: _shaderLens
                                ? _Capsule(lens)
                                : _LensEnds(lens),
                            child: Transform.scale(
                              scaleX: lerpDouble(1, _Metrics.magnifyX, t),
                              scaleY: lerpDouble(1, _Metrics.magnifyY, t),
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
          ),
          if (lensShown)
            Positioned.fromRect(
              rect: lens.shift(const Offset(_Metrics.inset, _Metrics.inset)),
              child: _shaderLens
                  ? withTabLens(
                      context,
                      const GlassGroup(
                        mode: GlassRenderMode.shader,
                        child: LiquidGlass(
                          glass: Glass.clear,
                          mode: GlassRenderMode.shader,
                          child: SizedBox.expand(),
                        ),
                      ),
                    )
                  : GlassGroup(
                      mode: widget.mode,
                      child: LiquidGlass(
                        glass: Glass.clear,
                        mode: widget.mode,
                        child: const SizedBox.expand(),
                      ),
                    ),
            ),
          // Native clear glass refracts and blurs the copy beneath it; iOS's
          // lens keeps its middle sharp and bends only the rim, so a sharp
          // copy goes on top, faded out towards the rim. (The shader lens
          // keeps the middle sharp itself.)
          if (lensShown && !_shaderLens)
            Positioned.fromRect(
              rect: lens.shift(const Offset(_Metrics.inset, _Metrics.inset)),
              child: IgnorePointer(
                child: _RimFade(
                  rim: _Metrics.lensRim,
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
                            scaleX: lerpDouble(1, _Metrics.magnifyX, t),
                            scaleY: lerpDouble(1, _Metrics.magnifyY, t),
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
        const SizedBox(width: _Metrics.pillExtra / 2),
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

/// Fades [child] out over the [rim] at its leading and trailing ends.
class _RimFade extends StatelessWidget {
  const _RimFade({required this.rim, required this.child});

  final double rim;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      Gradient fade(Axis axis) {
        final extent = axis == Axis.horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        final f = extent <= 0 ? 0.5 : (rim / extent).clamp(0.0, 0.5);
        const clear = Color(0x00000000);
        const solid = Color(0xFF000000);
        return LinearGradient(
          begin: axis == Axis.horizontal
              ? Alignment.centerLeft
              : Alignment.topCenter,
          end: axis == Axis.horizontal
              ? Alignment.centerRight
              : Alignment.bottomCenter,
          colors: const [clear, solid, solid, clear],
          stops: [0, f, 1 - f, 1],
        );
      }

      return ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => fade(Axis.horizontal).createShader(bounds),
        child: child,
      );
    },
  );
}

/// The rounded ends of [lens] (one corner radius in from each side): the
/// only part of the lens whose glass refracts the tabs beneath it. Its
/// middle shows the sharp copy on top, and its top and bottom rims refract
/// the bar, as iOS's lens does.
class _LensEnds extends CustomClipper<Path> {
  const _LensEnds(this.lens);

  final Rect lens;

  @override
  Path getClip(Size size) {
    final r = lens.height / 2;
    final capsule = Path()
      ..addRRect(RRect.fromRectAndRadius(lens, Radius.circular(r)));
    final ends = Path()
      ..addRect(Rect.fromLTRB(lens.left, lens.top, lens.left + r, lens.bottom))
      ..addRect(
        Rect.fromLTRB(lens.right - r, lens.top, lens.right, lens.bottom),
      );
    return Path.combine(PathOperation.intersect, capsule, ends);
  }

  @override
  bool shouldReclip(_LensEnds old) => old.lens != lens;
}

/// Just [capsule].
class _Capsule extends CustomClipper<Path> {
  const _Capsule(this.capsule);

  final Rect capsule;

  @override
  Path getClip(Size size) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(capsule, Radius.circular(capsule.height / 2)),
    );

  @override
  bool shouldReclip(_Capsule old) => old.capsule != capsule;
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

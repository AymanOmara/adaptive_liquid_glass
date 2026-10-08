import 'dart:async' show Timer;
import 'dart:math' as math;
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
import 'package:flutter/services.dart' show HapticFeedback;

import '../badge/glass_badge.dart';
import '../core/cupertino_l10n.dart';
import '../core/effective_glass_mode.dart';
import '../core/glass.dart';
import '../core/glass_colors.dart';
import '../core/glass_environment.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_system_colors.dart';
import '../core/liquid_glass_theme.dart';
import '../core/render_mode_resolver.dart';
import '../foreground/glass_foreground.dart';
import '../group/glass_group.dart';
import '../liquid_glass.dart';
import '../platform/glass_platform.dart';
import 'bar_glow.dart';
import 'bar_shadow.dart';
import 'capsule_clipper.dart';
import 'glass_search_tab_button.dart';
import 'glass_tab_bar_item.dart';
import 'hole_clipper.dart';
import 'lens_ends_clipper.dart';
import 'rim_fade.dart';
import 'tab_bar_fill_scope.dart';
import 'tab_bar_metrics.dart';
import 'tab_lens.dart';
import 'tab_lens_content.dart';
import 'tab_lens_program.dart';

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
/// Unselected tabs take iOS's tab bar label colour, dark or light by what
/// is behind the glass.
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
    this.itemWidth = 86.0,
    this.height = 62,
    this.enableFeedback = true,
    this.onSearch,
    this.searchLabel,
  }) : assert(items.length >= 2, 'A tab bar needs at least two tabs.');

  /// The tabs, in reading order.
  final List<GlassTabBarItem> items;

  /// The index of the selected tab.
  final int selectedIndex;

  /// Called with the index of the tab the user picked; the bar shows
  /// [selectedIndex] until the parent rebuilds it with the new one.
  final ValueChanged<int> onSelected;

  /// The selected tab's icon and label, and the tabs under the lens.
  /// Defaults to iOS 26's tab bar blue, measured from SwiftUI's `TabView`,
  /// or Material 3's colours on the Material path.
  final Color? selectedColor;

  /// The pill behind the selected tab at rest. Defaults to the fill
  /// iOS 26.4's tab bar draws (black at 7%, white at 14.5% in dark mode),
  /// or Material 3's indicator on the Material path.
  final Color? indicatorColor;

  /// The bar's glass. Defaults to the theme's default glass.
  final Glass? glass;

  /// The rendering path for the bar and its lens; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// The distance between neighbouring tabs at most (the selection pill is
  /// 7.98 wider, as on iOS). Tabs move closer evenly when the bar would not
  /// fit the width it is given.
  final double itemWidth;

  /// The bar's height.
  final double height;

  /// Whether dragging the lens onto another tab plays a selection haptic,
  /// as iOS does. The Material path follows Material's own feedback.
  final bool enableFeedback;

  /// Adds iOS 26's search tab (SwiftUI's `Tab(role: .search)`): a glass
  /// circle beside the bar, which then fills the rest of the width.
  /// Called when it is tapped; null shows none.
  final VoidCallback? onSearch;

  /// What assistive tech reads for the search tab. Defaults to the
  /// localized "Search".
  final String? searchLabel;

  @override
  State<GlassTabBar> createState() => _GlassTabBarState();
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

  /// The bar's growth around a held lens: 0 at rest, 1 grown (see
  /// TabBarMetrics.grow). Frozen when the finger lifts; it goes back once
  /// the lens settles, so a quick tap leaves the bar as it is.
  late final AnimationController _grow = AnimationController.unbounded(
    vsync: this,
  );

  void _springGrow(double target) {
    if (_reduceMotion) {
      _grow.value = target;
    } else {
      _grow
          .animateWith(
            SpringSimulation(
              TabBarMetrics.grow,
              _grow.value,
              target,
              _grow.velocity,
            ),
          )
          .whenCompleteOrCancel(() {
            // A spring stops within its tolerance: land the bar on its
            // size.
            if (mounted &&
                !_grow.isAnimating &&
                (_grow.value - target).abs() < 0.01) {
              _grow.value = target;
            }
          });
    }
  }

  /// Whether the lens is up: from touch-down until it settles. A quick
  /// tap selects before the lens has visibly grown, and the new tab must
  /// not flash its tint under it.
  bool _lensUp = false;

  /// The lens settling into the pill, with the bar shrinking back.
  void _settle() {
    _lensUp = false;
    _springPress(TabBarMetrics.release, 0);
    _springGrow(0);
  }

  /// Drives [_x] towards the finger with a spring integrated every frame.
  /// Restarting a spring simulation on each touch (every ~4 frames) left
  /// the lens still for the restart frame: a visible stutter.
  late final Ticker _followTicker = createTicker(_stepFollow);
  double _followTarget = 0;
  double _followVelocity = 0;
  Duration _followLast = Duration.zero;

  /// The lens's velocity in slots per second, whatever drives it.
  double get _xVelocity => _followTicker.isActive
      ? _followVelocity
      : (_x.isAnimating ? _x.velocity : 0.0);

  bool get _xMoving => _followTicker.isActive || _x.isAnimating;

  /// 1 while the lens springs across to a tab (not following a finger),
  /// easing to 0 over its last tenth of a slot.
  double get _travelling {
    if (_followTicker.isActive || !_x.isAnimating) return 0;
    final left = (_xTarget - _x.value).abs();
    // A longer hop travels narrower: 1 for one tab, about 1.5 for two.
    final hop = math.pow(_xHop.clamp(0.0, 2.0), 0.6);
    return hop * (left / 0.1).clamp(0.0, 1.0);
  }

  /// Where [_x]'s spring is heading.
  double _xTarget = 0;

  /// How far (slots) [_x]'s spring set out to go.
  double _xHop = 0;

  /// The light on the bar: 0 at rest, 1 while the lens is held (lit around
  /// it, see BarGlow), 2 while it is dragged (a softer glow), as on iOS.
  late final AnimationController _light = AnimationController.unbounded(
    vsync: this,
  );

  /// Whether the held lens has been dragged since it was pressed.
  bool _dragging = false;

  void _springLight(SpringDescription spring, double target) {
    if (_reduceMotion) {
      _light.value = target;
    } else {
      _light.animateWith(
        SpringSimulation(spring, _light.value, target, _light.velocity),
      );
    }
  }

  /// Extra lens overhang per side from the sideways wobble, in points.
  final ValueNotifier<double> _wobble = ValueNotifier(0);
  late final Ticker _wobbleTicker = createTicker(_stepWobble);
  double _wobbleVelocity = 0;
  double _lastVelocity = 0;
  Duration _lastTick = Duration.zero;

  /// Whether the lens is drawn with the package's shader (fitted to iOS's
  /// tab lens); without shader support, or when [GlassTabBar.mode] asks for
  /// another path, it is the requested glass.
  bool _shaderLens = false;

  /// Whether the bar's glass is drawn by the shader, which then needs the
  /// bar's own shadow (BarShadow); UIKit draws native glass's.
  bool _shaderBar = false;

  /// The bar's path: with the shader lens the bar is shader glass too, so
  /// the lens can refract it (native glass is invisible to the shader). An
  /// explicit [GlassTabBar.mode] wins.
  GlassRenderMode? get _barMode =>
      widget.mode ?? (_shaderLens ? GlassRenderMode.shader : null);

  /// Margin around the tab row in the lens content layer, so the lens
  /// (which outgrows the row) lies inside it.
  static const double _lensPad = 24;

  bool _placed = false;
  bool _held = false;

  /// Where the finger is, in visual slots.
  double _finger = 0;

  /// The tab under the finger as last announced by a haptic.
  int _fingerSlot = 0;

  int get _nearestSlot => _finger.round().clamp(0, _count - 1);

  /// The spacing of the tabs as last laid out.
  late double _itemWidth = widget.itemWidth;

  int get _count => widget.items.length;

  /// How much wider than the tab spacing the pill is, as last laid out.
  double _pillExtra = TabBarMetrics.pillExtra;

  double get _pillWidth => _itemWidth + _pillExtra;

  double get _rowWidth => _pillWidth + (_count - 1) * _itemWidth;

  double get _contentHeight => widget.height - TabBarMetrics.inset * 2;

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  /// Visual slot (left to right) of tab [index].
  int _slot(int index) => _rtl ? _count - 1 - index : index;

  double get _middle => (_count - 1) / 2;

  /// [dx] (pixels from the bar's left edge) in visual slots.
  double _toSlots(double dx) =>
      (dx - TabBarMetrics.inset - _pillWidth / 2) / _itemWidth;

  /// Where the lens heads for a finger at [finger] (visual slots).
  double _lensTarget(double finger) {
    final reach =
        TabBarMetrics.lensGain * _middle + TabBarMetrics.lensReach / _itemWidth;
    return _middle +
        (TabBarMetrics.lensGain * (finger - _middle)).clamp(-reach, reach);
  }

  /// Pixels from the row's left edge of visual slot position [slots].
  double _toPixels(double slots) => _pillWidth / 2 + slots * _itemWidth;

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _springX(SpringDescription spring, double target) {
    final velocity = _xVelocity;
    _stopFollow();
    if (_reduceMotion) {
      _x.value = target;
    } else {
      _xTarget = target;
      _xHop = (target - _x.value).abs();
      _x.animateWith(SpringSimulation(spring, _x.value, target, velocity));
    }
  }

  /// Moves the follow spring's target; starts it, carrying the lens's
  /// current velocity, when it is not running.
  void _follow(double target) {
    _followTarget = target;
    if (_reduceMotion) {
      _x.value = target;
      return;
    }
    if (_followTicker.isActive) return;
    _followVelocity = _xVelocity;
    _x.stop();
    _followLast = Duration.zero;
    _followTicker.start();
  }

  void _stopFollow() {
    if (_followTicker.isActive) _followTicker.stop();
  }

  void _stepFollow(Duration elapsed) {
    // The first tick has no elapsed time; step a frame so the lens never
    // stands still.
    final dt = elapsed == Duration.zero
        ? 1 / 60
        : ((elapsed - _followLast).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _followLast = elapsed;
    final spring = TabBarMetrics.follow;
    final k = spring.stiffness / spring.mass;
    final c = spring.damping / spring.mass;
    const steps = 4;
    final h = dt / steps;
    var x = _x.value;
    for (var i = 0; i < steps; i++) {
      _followVelocity += (-k * (x - _followTarget) - c * _followVelocity) * h;
      x += _followVelocity * h;
    }
    _x.value = x;
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
      _lastVelocity = _xVelocity;
      return;
    }
    final velocity = _xVelocity;
    // Only a dragged lens wobbles: SwiftUI's TabView (iOS 26.4) keeps a
    // lens travelling to a pressed tab at its height (Kept's wobble was
    // measured dragging).
    final acceleration = _dragging
        ? (velocity - _lastVelocity) / dt * _itemWidth
        : 0.0;
    _lastVelocity = velocity;
    final spring = TabBarMetrics.wobble;
    final k = spring.stiffness / spring.mass;
    final c = spring.damping / spring.mass;
    // Semi-implicit Euler in small steps for stability.
    const steps = 4;
    final h = dt / steps;
    var y = _wobble.value;
    for (var i = 0; i < steps; i++) {
      final a =
          -k * y -
          c * _wobbleVelocity -
          k * TabBarMetrics.wobbleGain * acceleration;
      _wobbleVelocity += a * h;
      y += _wobbleVelocity * h;
    }
    _wobble.value = y;
    if (!_held && !_xMoving && y.abs() < 0.01 && _wobbleVelocity.abs() < 0.01) {
      _wobble.value = 0;
      _wobbleVelocity = 0;
      _wobbleTicker.stop();
    }
  }

  void _startWobble() {
    if (_reduceMotion || _wobbleTicker.isActive) return;
    _lastTick = Duration.zero;
    _lastVelocity = _xVelocity;
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
      _springX(TabBarMetrics.slide, _slot(widget.selectedIndex).toDouble());
    } else if (old.items.length != widget.items.length) {
      _x.value = _slot(widget.selectedIndex).toDouble();
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _reliftTimer?.cancel();
    _followTicker.dispose();
    _grow.dispose();
    _light.dispose();
    _wobbleTicker.dispose();
    _wobble.dispose();
    _x.dispose();
    _press.dispose();
    super.dispose();
  }

  void _down(DragDownDetails details) {
    _held = true;
    _lensUp = true;
    _finger = _toSlots(details.localPosition.dx);
    _fingerSlot = _nearestSlot;
    _cancelPendingRelease();
    _cancelRelift();
    _holdTimer?.cancel();
    _holdTimer = Timer(TabBarMetrics.tapHold, () {
      _holdTimer = null;
      final settle = _pendingSettle;
      _pendingSettle = null;
      if (mounted && !_held) settle?.call();
    });
    _dragging = false;
    _springLight(TabBarMetrics.light, 1);
    _springGrow(1);
    // The lens grows at the current selection and travels to the finger,
    // as iOS does (a tap on a far tab sends it across the bar). Sent
    // across, it pops up at once and, if still held when it arrives,
    // settles and lifts again (iOS 26.4).
    final target = _lensTarget(_finger);
    final travels = (target - _x.value).abs() > 0.5 && !_reduceMotion;
    _springPress(travels ? TabBarMetrics.pop : TabBarMetrics.press, 1);
    _springX(TabBarMetrics.travel, target);
    if (travels) {
      _reliftAt = target;
      _x.addListener(_reliftOnArrival);
    }
    _startWobble();
  }

  void _drag(DragUpdateDetails details) {
    if (_cancelRelift()) _springPress(TabBarMetrics.press, 1);
    _finger = _toSlots(details.localPosition.dx);
    _follow(_lensTarget(_finger));
    final slot = _nearestSlot;
    if (slot != _fingerSlot) {
      _fingerSlot = slot;
      if (widget.enableFeedback) HapticFeedback.selectionClick();
    }
    if (!_dragging) {
      _dragging = true;
      _springLight(TabBarMetrics.light, 2);
    }
  }

  void _release(double velocity) {
    _held = false;
    _cancelRelift();
    // The bar stays as grown as it is until the lens settles.
    _grow.stop();
    _springLight(TabBarMetrics.lightOff, 0);
    final slot = _nearestSlot;
    final index = _rtl ? _count - 1 - slot : slot;
    final travelling = (_x.value - slot).abs() > 0.15;
    _springX(
      travelling ? TabBarMetrics.travel : TabBarMetrics.slide,
      slot.toDouble(),
    );
    if (travelling && !_reduceMotion && _holdTimer == null) {
      // iOS keeps a held lens until it arrives, then settles it into the
      // pill. A quick tap's lens settles at tapHold, still travelling.
      _arrival = slot.toDouble();
      _x.addListener(_settleOnArrival);
    } else {
      _shrink(_settle);
    }
    if (index != widget.selectedIndex) {
      widget.onSelected(index);
      // The parent owns the selection: if it kept the old one, the pill
      // and lens go back to it, so they never part from the tint.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_held && widget.selectedIndex != index) _reconcile();
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  /// Springs the pill (settling any lens) back to [GlassTabBar.selectedIndex].
  void _reconcile() {
    _cancelPendingRelease();
    _settle();
    _springX(TabBarMetrics.slide, _slot(widget.selectedIndex).toDouble());
  }

  /// Runs out TabBarMetrics.tapHold after the last touch-down; null once
  /// the lens has been up that long.
  Timer? _holdTimer;

  /// A quick tap's settle, waiting for [_holdTimer].
  VoidCallback? _pendingSettle;

  /// Where a released lens is travelling to; null when not waiting.
  double? _arrival;

  void _settleOnArrival() {
    final target = _arrival;
    if (target == null || (_x.value - target).abs() > 0.15) return;
    _arrival = null;
    _x.removeListener(_settleOnArrival);
    _shrink(_settle);
  }

  /// Where a popped, held lens is travelling to; null when not waiting.
  double? _reliftAt;

  /// Lifts the lens again TabBarMetrics.relift after it settled.
  Timer? _reliftTimer;

  void _reliftOnArrival() {
    final target = _reliftAt;
    if (target == null || (_x.value - target).abs() > 0.15) return;
    _reliftAt = null;
    _x.removeListener(_reliftOnArrival);
    if (!_held) return;
    _springPress(TabBarMetrics.release, 0);
    _reliftTimer = Timer(TabBarMetrics.relift, () {
      _reliftTimer = null;
      if (mounted && _held) _springPress(TabBarMetrics.press, 1);
    });
  }

  /// Stops a pending relift; true when the lens was settling for one.
  bool _cancelRelift() {
    _reliftAt = null;
    _x.removeListener(_reliftOnArrival);
    final timer = _reliftTimer;
    _reliftTimer = null;
    timer?.cancel();
    return timer != null;
  }

  void _cancelPendingRelease() {
    _arrival = null;
    _x.removeListener(_settleOnArrival);
    _pendingSettle = null;
  }

  /// Runs [settle] (the lens shrinking into the pill) now, or once the
  /// lens has been up for TabBarMetrics.tapHold.
  void _shrink(VoidCallback settle) {
    if (_reduceMotion || _holdTimer == null) {
      settle();
    } else {
      _pendingSettle = settle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSearch = widget.onSearch;
    if (onSearch == null) return _sizedBar();
    // The search tab: the bar fills what the circle leaves.
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width:
                constraints.maxWidth -
                GlassSearchTabButton.size -
                GlassSearchTabButton.gap,
            child: TabBarFillScope(child: _sizedBar()),
          ),
          const SizedBox(width: GlassSearchTabButton.gap),
          // The circle is the bar's material (UIKit draws both), with the
          // bar's shadow in shader mode.
          CustomPaint(
            painter: _searchShader(context) ? const BarShadow() : null,
            child: withTabBarGlass(
              context,
              GlassSearchTabButton(
                onPressed: onSearch,
                semanticLabel:
                    widget.searchLabel ??
                    cupertinoL10n(context).searchTextFieldPlaceholderLabel,
                glass: widget.glass,
                mode: _barMode,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Whether the search circle is drawn by the shader (and so needs the
  /// bar's shadow). Resolved here: the bar's own flags are set while it
  /// lays out, after this circle is built.
  bool _searchShader(BuildContext context) {
    final environment = GlassPlatform.instance.environment.value;
    final requested = widget.mode ?? LiquidGlassTheme.of(context).defaultMode;
    final lens =
        environment.shaderSupported &&
        (widget.mode == null ||
            resolveGlassMode(requested: requested, environment: environment) ==
                EffectiveGlassMode.shader);
    return resolveGlassMode(
          requested: widget.mode ?? (lens ? GlassRenderMode.shader : requested),
          environment: environment,
        ) ==
        EffectiveGlassMode.shader;
  }

  Widget _sizedBar() => LayoutBuilder(
    builder: (context, constraints) {
      final fills = TabBarFillScope.of(context);
      _pillExtra = fills
          ? TabBarMetrics.pillExtraFilled
          : TabBarMetrics.pillExtra;
      final fit =
          (constraints.maxWidth - TabBarMetrics.inset * 2 - _pillExtra) /
          _count;
      _itemWidth = fit < widget.itemWidth || fills ? fit : widget.itemWidth;
      return ValueListenableBuilder<GlassEnvironment>(
        valueListenable: GlassPlatform.instance.environment,
        builder: (context, environment, _) {
          final mode = resolveGlassMode(
            requested: widget.mode ?? LiquidGlassTheme.of(context).defaultMode,
            environment: environment,
          );
          // A bar asked for another path (native) keeps a lens of that
          // path: the shader cannot see native glass, so a shader lens
          // over it drew black.
          _shaderLens =
              environment.shaderSupported &&
              (widget.mode == null || mode == EffectiveGlassMode.shader);
          if (_shaderLens) TabLensProgram.instance.load();
          _shaderBar =
              resolveGlassMode(
                requested: _barMode ?? LiquidGlassTheme.of(context).defaultMode,
                environment: environment,
              ) ==
              EffectiveGlassMode.shader;
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
      width: _rowWidth + TabBarMetrics.inset * 2,
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
      widget.selectedColor ?? GlassColors.tabBarSelected,
      context,
    );
    final indicator = CupertinoDynamicColor.resolve(
      widget.indicatorColor ?? GlassColors.tabBarPill,
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
          animation: Listenable.merge([_x, _press, _grow, _wobble, _light]),
          builder: (context, _) => _bar(_press.value, selected, indicator),
        ),
      ),
    );
  }

  Widget _bar(double p, Color selected, Color indicator) {
    // p springs past 0 and 1; the lens shows only while it is above 0,
    // but the pill and lens sizes follow p itself (the pill squashes).
    final t = p.clamp(0.0, 1.0);
    // Only a lens that is held, not yet settled or still visibly grown is
    // drawn: a release spring rebounds a hair above zero, and a hair-thin
    // lens would still refract a ghost of the tabs over the pill.
    // (The release spring's second rebound peaks near 0.016.)
    final lensShown = _held || _lensUp || p > 0.05;
    final lensContent =
        _shaderLens && TabLensProgram.instance.program.value != null;
    final x = _toPixels(_x.value);
    // The wobble belongs to the held lens: it fades with it and never
    // reaches the pill.
    final wobble = _wobble.value * t;
    // 0 held, 1 dragged (the bar's light goes from 1 to 2).
    final dragged = (_light.value - 1).clamp(0.0, 1.0);
    final lensGrowY =
        TabBarMetrics.lensGrowY - TabBarMetrics.lensDragDropY * dragged;
    final lens = Rect.fromCenter(
      center: Offset(x, _contentHeight / 2),
      width:
          _pillWidth +
          TabBarMetrics.lensGrowX * p -
          TabBarMetrics.lensTravelNarrow * _travelling * t,
      height: _contentHeight + lensGrowY * p + wobble * 2,
    );
    // The bar grows on its own spring, not the lens's (see _grow).
    final g = _grow.value;
    final lean = TabBarMetrics.growLean * (x - _rowWidth / 2) * g;
    final growX = TabBarMetrics.growX * g;
    final growY = TabBarMetrics.growY * g;
    // The bar's glass reaches past the row by the inset plus its growth.
    final glowInsetX = TabBarMetrics.inset + growX;
    final glowInsetY = TabBarMetrics.inset + growY;
    // The glow follows the lens, held or dragged; a drag softens it
    // (SwiftUI's `TabView`, iOS 26.4, over black: about 50 by the lens and
    // 30 away while held, 45 and 35 mid-drag).
    final light = _light.value;
    final glow =
        light.clamp(0.0, 1.0) *
        (1 - TabBarMetrics.dragGlowDrop * (light - 1).clamp(0.0, 1.0));
    final baseRow = ClipPath(
      clipper: HoleClipper(lensShown ? lens : null),
      child: _row(
        // Gated like the lens, not on p == 0: the settling spring crosses
        // zero several times and would flicker the tint off and on.
        (i) => !lensShown && i == widget.selectedIndex ? selected : null,
        semantics: true,
      ),
    );
    final magnify = Offset(
      lerpDouble(1, TabBarMetrics.magnifyX, t)!,
      lerpDouble(1, TabBarMetrics.magnifyY, t)!,
    );
    return SizedBox(
      width: _rowWidth + TabBarMetrics.inset * 2,
      height: widget.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -growX + lean,
            right: -growX - lean,
            top: -growY,
            bottom: -growY,
            child: CustomPaint(
              painter: _shaderBar ? const BarShadow() : null,
              child: withTabBarGlass(
                context,
                light: _light.value,
                GlassGroup(
                  mode: _barMode,
                  child: LiquidGlass(
                    glass: widget.glass,
                    mode: _barMode,
                    child: Center(
                      child: SizedBox(
                        width: _rowWidth,
                        height: _contentHeight,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (_shaderLens && glow > 0)
                              Positioned(
                                left: -glowInsetX,
                                top: -glowInsetY,
                                width: _rowWidth + glowInsetX * 2,
                                height: _contentHeight + glowInsetY * 2,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    _contentHeight / 2 + glowInsetY,
                                  ),
                                  child: CustomPaint(
                                    painter: BarGlow(
                                      centre: Offset(
                                        x + glowInsetX,
                                        _contentHeight / 2 + glowInsetY,
                                      ),
                                      opacity: TabBarMetrics.glow * glow,
                                    ),
                                  ),
                                ),
                              ),
                            // The pill grows with the lens and cross-fades
                            // with the bar's light, so the young lens reads
                            // as bright as the pill, evenly (iOS 26.4: no
                            // pill inside it, no flash as the light comes).
                            Positioned.fromRect(
                              rect: lens,
                              child: Opacity(
                                opacity: 1 - light.clamp(0.0, 1.0),
                                child: DecoratedBox(
                                  decoration: ShapeDecoration(
                                    shape: const StadiumBorder(),
                                    color: indicator,
                                  ),
                                ),
                              ),
                            ),
                            // Under a held lens the row has a hole filled by a
                            // magnified, tinted copy. Without the content
                            // shader both lie beneath the lens, so its glass
                            // refracts them (bending them at its rim).
                            if (!lensContent) baseRow,
                            if (lensShown && !lensContent)
                              ClipPath(
                                // The shader lens bends the whole copy; native
                                // glass only gets the ends (see LensEndsClipper).
                                clipper: _shaderLens
                                    ? CapsuleClipper(lens)
                                    : LensEndsClipper(lens),
                                child: _row(
                                  (_) => selected,
                                  semantics: false,
                                  scale: magnify,
                                ),
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
          if (lensShown)
            Positioned.fromRect(
              rect: lens.shift(
                const Offset(TabBarMetrics.inset, TabBarMetrics.inset),
              ),
              child: _shaderLens
                  ? withTabLens(
                      context,
                      bend: t,
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
          // With the content shader the tabs lie over the lens glass, which
          // refracts only the bar and the page behind them (iOS's lens never
          // shows the plain tabs).
          if (lensContent)
            Positioned(
              left: TabBarMetrics.inset + lean,
              top: TabBarMetrics.inset,
              width: _rowWidth,
              height: _contentHeight,
              child: baseRow,
            ),
          // With the content shader the tinted tabs lie over the lens glass,
          // refracted on their own, so the glass brightens only what is
          // behind them (as iOS does).
          if (lensShown && lensContent)
            Positioned(
              left: TabBarMetrics.inset + lean - _lensPad,
              top: TabBarMetrics.inset - _lensPad,
              width: _rowWidth + _lensPad * 2,
              height: _contentHeight + _lensPad * 2,
              child: TabLensContent(
                box: Size(
                  _rowWidth + _lensPad * 2,
                  _contentHeight + _lensPad * 2,
                ),
                lens: lens.shift(Offset(_lensPad - lean, _lensPad)),
                fallback: const SizedBox.shrink(),
                child: ColoredBox(
                  // Keeps the filter's layer the size of the box.
                  color: GlassColors.invisible,
                  child: Padding(
                    padding: const EdgeInsets.all(_lensPad),
                    child: _row(
                      (_) => selected,
                      semantics: false,
                      scale: magnify,
                    ),
                  ),
                ),
              ),
            ),
          // Native clear glass refracts and blurs the copy beneath it; iOS's
          // lens keeps its middle sharp and bends only the rim, so a sharp
          // copy goes on top, faded out towards the rim. (The shader lens
          // keeps the middle sharp itself.)
          if (lensShown && !_shaderLens)
            Positioned.fromRect(
              rect: lens.shift(
                const Offset(TabBarMetrics.inset, TabBarMetrics.inset),
              ),
              child: IgnorePointer(
                child: RimFade(
                  rim: TabBarMetrics.lensRim,
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
                          child: _row(
                            (_) => selected,
                            semantics: false,
                            scale: magnify,
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

  /// The tabs; [colorOf] null leaves a tab to the tab bar's label colour.
  Widget _row(
    Color? Function(int index) colorOf, {
    required bool semantics,
    Offset scale = const Offset(1, 1),
  }) {
    final row = Row(
      children: [
        SizedBox(width: _pillExtra / 2),
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
                child: _scaled(
                  scale,
                  Builder(
                    builder: (context) {
                      final c = colorOf(i) ?? _labelColor(context);
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // The glyph overhangs the bottom of its slot: iOS sets
                          // the icon and label closer than a 28 pt box allows.
                          SizedBox(
                            height: TabBarMetrics.iconSlot,
                            child: OverflowBox(
                              maxHeight:
                                  TabBarMetrics.iconSize +
                                  TabBarMetrics.iconDrop,
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: TabBarMetrics.iconDrop,
                                ),
                                child: _icon(
                                  widget.items[i],
                                  i == widget.selectedIndex,
                                  c,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: TabBarMetrics.labelGap),
                          // UIKit sizes a label to whole points and sets
                          // its text at the start, so the ink sits a little
                          // towards the start of the tab.
                          IntrinsicWidth(
                            stepWidth: 1,
                            child: Text(
                              widget.items[i].label,
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: TabBarMetrics.label.copyWith(color: c),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    return semantics ? row : ExcludeSemantics(child: row);
  }

  /// Unselected tabs: iOS's tab bar label, dark over light content and
  /// light over dark (GlassForeground's sampled brightness).
  static Color _labelColor(BuildContext context) =>
      GlassForeground.backgroundBrightnessOf(context) == Brightness.light
      ? GlassColors.tabBarLabel.color
      : GlassColors.tabBarLabel.darkColor;

  /// iOS magnifies each tab under the lens about its own centre, so a tab
  /// at the lens's rim stays in view.
  Widget _scaled(Offset scale, Widget child) => scale == const Offset(1, 1)
      ? child
      : Transform.scale(scaleX: scale.dx, scaleY: scale.dy, child: child);

  /// The tab's icon, with its badge at the top trailing corner.
  Widget _icon(GlassTabBarItem item, bool isSelected, Color? color) {
    final icon = Icon(
      isSelected ? item.activeIcon ?? item.icon : item.icon,
      size: TabBarMetrics.iconSize,
      color: color,
    );
    final badge = item.badge;
    if (badge == null) return icon;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        // Top leading corner at badgeOffset from the icon's centre: a
        // longer count grows towards the end, as on iOS.
        PositionedDirectional(
          start: TabBarMetrics.iconSize / 2 + TabBarMetrics.badgeOffset.dx,
          top: TabBarMetrics.iconSize / 2 + TabBarMetrics.badgeOffset.dy,
          child: badge.isEmpty
              // iOS draws an empty badge as a plain circle.
              ? SizedBox.square(
                  dimension: TabBarMetrics.emptyBadge,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: const CircleBorder(),
                      color: CupertinoDynamicColor.resolve(
                        GlassSystemColors.red,
                        context,
                      ),
                    ),
                  ),
                )
              // Any glass mode draws the iOS badge; this bar is never
              // Material.
              : GlassBadge(label: badge, mode: GlassRenderMode.shader),
        ),
      ],
    );
  }
}

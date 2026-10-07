import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/badge/badge_metrics.dart';
import 'package:adaptive_liquid_glass/src/core/glass_colors.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/tab_bar/bar_shadow.dart';
import 'package:adaptive_liquid_glass/src/tab_bar/glass_search_tab_button.dart';
import 'package:adaptive_liquid_glass/src/tab_bar/lens_ends_clipper.dart';
import 'package:adaptive_liquid_glass/src/tab_bar/search_glyph.dart';
import 'package:adaptive_liquid_glass/src/tab_bar/tab_bar_fill_scope.dart';
import 'package:adaptive_liquid_glass/src/tab_bar/tab_bar_metrics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Badge, NavigationBar;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

const _items = [
  GlassTabBarItem(icon: CupertinoIcons.clock_fill, label: 'History'),
  GlassTabBarItem(icon: CupertinoIcons.text_quote, label: 'Snippets'),
  GlassTabBarItem(icon: CupertinoIcons.gear_solid, label: 'Settings'),
];

const _blue = Color(0xFF0000FF);

/// A tab bar that keeps its own selection, and records every pick.
class _Harness extends StatefulWidget {
  const _Harness(
    this.picks, {
    this.items = _items,
    this.enableFeedback = true,
    this.selectedColor = _blue,
    this.mode,
  });

  final List<int> picks;
  final List<GlassTabBarItem> items;
  final bool enableFeedback;
  final Color? selectedColor;
  final GlassRenderMode? mode;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) => GlassTabBar(
    items: widget.items,
    selectedIndex: _selected,
    selectedColor: widget.selectedColor,
    mode: widget.mode,
    enableFeedback: widget.enableFeedback,
    onSelected: (i) {
      widget.picks.add(i);
      setState(() => _selected = i);
    },
  );
}

/// A fresh, growable record of picks.
List<int> _picks() => <int>[];

Color? _labelColor(WidgetTester t, String label) =>
    t.widget<Text>(find.text(label).first).style?.color;

/// The clear glass lens is shown only while the bar is held.
Finder get _lens =>
    find.byWidgetPredicate((w) => w is LiquidGlass && w.glass == Glass.clear);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  for (final (name, variant, host) in [
    ('shader', ios, plainHost),
    ('Material', android, (Widget w) => appHost(w)),
  ]) {
    testWidgets('$name: the selected tab is tinted, the others are not', (
      t,
    ) async {
      shaderEnv();
      await t.pumpWidget(host(_Harness(_picks())));
      expect(_labelColor(t, 'History'), _blue);
      expect(_labelColor(t, 'Snippets'), isNot(_blue));
      expect(_lens, findsNothing);
    }, variant: variant);

    testWidgets('$name: tapping a tab selects it', (t) async {
      shaderEnv();
      final picks = <int>[];
      await t.pumpWidget(host(_Harness(picks)));
      await t.tap(find.text('Settings'));
      await t.pumpAndSettle();
      expect(picks, [2]);
      expect(_labelColor(t, 'Settings'), _blue);
    }, variant: variant);
  }

  /// The pill's centre (it is at rest: the lens is gone).
  double pillX(WidgetTester t) => t
      .getCenter(
        find.byWidgetPredicate(
          (w) => w is DecoratedBox && w.decoration is ShapeDecoration,
        ),
      )
      .dx;

  Widget controlled(
    int selected,
    ValueChanged<int> onSelected,
    GlassRenderMode? mode,
  ) => plainHost(
    GlassTabBar(
      items: _items,
      selectedIndex: selected,
      selectedColor: _blue,
      mode: mode,
      onSelected: onSelected,
    ),
  );

  for (final mode in [null, GlassRenderMode.native]) {
    final name = mode == null ? 'shader' : mode.name;

    testWidgets('$name: a tap the parent rejects leaves pill and tint', (
      t,
    ) async {
      shaderEnv();
      final picks = <int>[];
      await t.pumpWidget(controlled(0, picks.add, mode));
      final home = pillX(t);
      await t.tap(find.text('Settings'));
      await t.pumpAndSettle();
      expect(picks, [2]);
      expect(_lens, findsNothing);
      expect(pillX(t), moreOrLessEquals(home, epsilon: 0.5));
      expect(
        pillX(t),
        moreOrLessEquals(t.getCenter(find.text('History')).dx, epsilon: 1),
      );
      expect(_labelColor(t, 'History'), _blue);
      expect(_labelColor(t, 'Settings'), isNot(_blue));
    }, variant: ios);

    testWidgets('$name: a tap the parent accepts moves pill and tint', (
      t,
    ) async {
      shaderEnv();
      await t.pumpWidget(plainHost(_Harness(_picks(), mode: mode)));
      await t.tap(find.text('Settings'));
      await t.pumpAndSettle();
      expect(_lens, findsNothing);
      expect(
        pillX(t),
        moreOrLessEquals(t.getCenter(find.text('Settings')).dx, epsilon: 1),
      );
      expect(_labelColor(t, 'Settings'), _blue);
      expect(_labelColor(t, 'History'), isNot(_blue));
    }, variant: ios);

    testWidgets('$name: an outside change moves pill and tint', (t) async {
      shaderEnv();
      await t.pumpWidget(controlled(0, (_) {}, mode));
      await t.pumpWidget(controlled(1, (_) {}, mode));
      await t.pumpAndSettle();
      expect(
        pillX(t),
        moreOrLessEquals(t.getCenter(find.text('Snippets')).dx, epsilon: 1),
      );
      expect(_labelColor(t, 'Snippets'), _blue);
      expect(_labelColor(t, 'History'), isNot(_blue));
    }, variant: ios);
  }

  testWidgets('shader mode: the bar paints its own lowered shadow', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(_Harness(_picks(), mode: GlassRenderMode.shader)),
    );
    final painted = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is BarShadow,
    );
    expect(painted, findsOneWidget);
    final painter = t.widget<CustomPaint>(painted).painter as BarShadow;
    expect(painter.offset, TabBarMetrics.shadowOffset);
    expect(painter.offset.dy, greaterThan(0));
  }, variant: ios);

  testWidgets('native mode: no painted shadow (UIKit draws it)', (t) async {
    // Native glass needs iOS 26; shaderEnv() is iOS 18, where native
    // falls back to the shader.
    GlassPlatform.instance.debugEnvironment = const GlassEnvironment(
      platform: TargetPlatform.iOS,
      iosMajorVersion: 26,
      reduceTransparency: false,
      shaderSupported: true,
    );
    await t.pumpWidget(
      plainHost(_Harness(_picks(), mode: GlassRenderMode.native)),
    );
    expect(
      find.byWidgetPredicate((w) => w is CustomPaint && w.painter is BarShadow),
      findsNothing,
    );
  }, variant: ios);

  testWidgets('holding shows the lens; dragging picks on release', (t) async {
    shaderEnv();
    final picks = <int>[];
    await t.pumpWidget(plainHost(_Harness(picks)));
    final from = t.getCenter(find.text('History'));
    final to = t.getCenter(find.text('Settings'));
    final gesture = await t.startGesture(from);
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(_lens, findsOneWidget);
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(picks, isEmpty, reason: 'nothing is picked while held');
    await gesture.up();
    await t.pumpAndSettle();
    expect(picks, [2]);
    expect(_lens, findsNothing);
  }, variant: ios);

  testWidgets('right to left: the first tab is on the right', (t) async {
    shaderEnv();
    final picks = <int>[];
    await t.pumpWidget(
      plainHost(_Harness(picks), direction: TextDirection.rtl),
    );
    expect(
      t.getCenter(find.text('History')).dx,
      greaterThan(t.getCenter(find.text('Settings')).dx),
    );
    await t.tap(find.text('Settings'));
    await t.pumpAndSettle();
    expect(picks, [2]);
  }, variant: ios);

  testWidgets('each tab is a selectable button for assistive tech', (t) async {
    shaderEnv();
    final semantics = t.ensureSemantics();
    final picks = <int>[];
    await t.pumpWidget(plainHost(_Harness(picks)));
    expect(
      t.getSemantics(find.text('History')),
      matchesSemantics(
        label: 'History',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    expect(
      t.getSemantics(find.text('Snippets')),
      matchesSemantics(
        label: 'Snippets',
        isButton: true,
        hasSelectedState: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    t.semantics.tap(find.semantics.byLabel('Snippets'));
    await t.pumpAndSettle();
    expect(picks, [1]);
    semantics.dispose();
  }, variant: ios);

  testWidgets('Reduce Motion: the pill jumps instead of sliding', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: _Harness(_picks()),
          ),
        ),
      ),
    );
    await t.tap(find.text('Settings'));
    await t.pump();
    // One frame later the pill is already under Settings: no spring.
    final pill = find.byWidgetPredicate(
      (w) => w is DecoratedBox && w.decoration is ShapeDecoration,
    );
    expect(
      t.getCenter(pill).dx,
      moreOrLessEquals(t.getCenter(find.text('Settings')).dx, epsilon: 0.5),
    );
    expect(_lens, findsNothing);
  }, variant: ios);

  testWidgets('five tabs shrink to fit a phone instead of overflowing', (
    t,
  ) async {
    shaderEnv();
    t.view.physicalSize = const Size(402, 874);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final picks = <int>[];
    final five = [
      for (final l in ['A', 'B', 'C', 'D', 'E'])
        GlassTabBarItem(icon: CupertinoIcons.circle, label: l),
    ];
    await t.pumpWidget(plainHost(_Harness(picks, items: five)));
    expect(t.takeException(), isNull);
    expect(t.getSize(find.byType(GlassTabBar)).width, lessThanOrEqualTo(402));
    // (402 - 2 × 4 inset - 7.98 pill) / 5 tabs, not the 86.0 that would
    // overflow.
    expect(
      t.getCenter(find.text('E')).dx - t.getCenter(find.text('D')).dx,
      moreOrLessEquals(
        (402 - 2 * TabBarMetrics.inset - TabBarMetrics.pillExtra) / 5,
        epsilon: 0.01,
      ),
    );
    await t.tap(find.text('E'));
    await t.pumpAndSettle();
    expect(picks, [4]);
    expect(_labelColor(t, 'E'), _blue);
  }, variant: ios);

  testWidgets('three tabs keep their full width when there is room', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_Harness(_picks())));
    expect(
      t.getSize(find.byType(GlassTabBar)).width,
      moreOrLessEquals(
        3 * 86.0 + TabBarMetrics.pillExtra + 2 * TabBarMetrics.inset,
        epsilon: 0.01,
      ),
    );
  }, variant: ios);

  testWidgets('a tab label box is a whole number of points wide', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_Harness(_picks())));
    for (final label in ['History', 'Snippets', 'Settings']) {
      final box = find
          .ancestor(
            of: find.text(label).first,
            matching: find.byType(IntrinsicWidth),
          )
          .first;
      final width = t.getSize(box).width;
      expect(width, width.roundToDouble());
      expect(
        width,
        greaterThanOrEqualTo(t.getSize(find.text(label).first).width),
      );
    }
  }, variant: ios);

  testWidgets('a tab icon sits iconDrop below the top of its slot', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_Harness(_picks())));
    // The OverflowBox's rect is its parent's (the slot); the child is
    // top-aligned inside it.
    final slot = find
        .ancestor(
          of: find.byType(Icon).first,
          matching: find.byType(OverflowBox),
        )
        .first;
    expect(
      t.getTopLeft(find.byType(Icon).first).dy - t.getTopLeft(slot).dy,
      moreOrLessEquals(TabBarMetrics.iconDrop, epsilon: 0.001),
    );
  }, variant: ios);

  testWidgets('the pill is pillExtra wider than the tab spacing', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_Harness(_picks())));
    final pill = find.byWidgetPredicate(
      (w) => w is DecoratedBox && w.decoration is ShapeDecoration,
    );
    expect(
      t.getSize(pill).width,
      moreOrLessEquals(86.0 + TabBarMetrics.pillExtra, epsilon: 0.01),
    );
  }, variant: ios);

  testWidgets('the selected tab shows its active icon', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        _Harness(
          _picks(),
          items: const [
            GlassTabBarItem(
              icon: CupertinoIcons.house,
              activeIcon: CupertinoIcons.house_fill,
              label: 'Home',
            ),
            GlassTabBarItem(
              icon: CupertinoIcons.person,
              activeIcon: CupertinoIcons.person_fill,
              label: 'Me',
            ),
          ],
        ),
      ),
    );
    expect(find.byIcon(CupertinoIcons.house_fill), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.person), findsOneWidget);
    await t.tap(find.text('Me'));
    await t.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.house), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.person_fill), findsOneWidget);
  }, variant: ios);

  testWidgets('a badge shows its text and is read with the tab', (t) async {
    shaderEnv();
    final semantics = t.ensureSemantics();
    await t.pumpWidget(
      plainHost(
        _Harness(
          _picks(),
          items: const [
            GlassTabBarItem(
              icon: CupertinoIcons.mail,
              label: 'Mail',
              badge: '3',
            ),
            GlassTabBarItem(icon: CupertinoIcons.gear, label: 'Settings'),
          ],
        ),
      ),
    );
    expect(find.text('3'), findsOneWidget);
    expect(
      t.getSemantics(find.text('Mail')),
      matchesSemantics(
        label: 'Mail',
        value: '3',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  }, variant: ios);

  testWidgets(
    'badges: 20-pt count capsule, 18-pt empty circle, top leading corner '
    'at badgeOffset',
    (t) async {
      shaderEnv();
      await t.pumpWidget(
        plainHost(
          _Harness(
            _picks(),
            items: const [
              GlassTabBarItem(
                icon: CupertinoIcons.mail,
                label: 'Mail',
                badge: '3',
              ),
              GlassTabBarItem(
                icon: CupertinoIcons.bell,
                label: 'Alerts',
                badge: '',
              ),
              GlassTabBarItem(
                icon: CupertinoIcons.gear,
                label: 'Settings',
                badge: 'New',
              ),
            ],
          ),
        ),
      );
      final count = find.ancestor(
        of: find.text('3'),
        matching: find.byType(GlassBadge),
      );
      final countSize = t.getSize(count);
      expect(BadgeMetrics.height, 20);
      expect(countSize.height, BadgeMetrics.height);
      expect(countSize.width, 20);
      final text = find.ancestor(
        of: find.text('New'),
        matching: find.byType(GlassBadge),
      );
      final textSize = t.getSize(text);
      expect(textSize.height, BadgeMetrics.height);
      expect(textSize.width, greaterThan(20));
      expect(find.byType(GlassBadge), findsNWidgets(2));
      final empty = find.descendant(
        of: find.byType(GlassTabBar),
        matching: find.byWidgetPredicate(
          (w) =>
              w is SizedBox &&
              w.width == TabBarMetrics.emptyBadge &&
              w.height == TabBarMetrics.emptyBadge,
        ),
      );
      expect(empty, findsOneWidget);
      expect(TabBarMetrics.emptyBadge, 18);

      void corner(Finder badge, Finder icon) {
        final delta = t.getTopLeft(badge) - t.getCenter(icon);
        expect(delta.dx, closeTo(TabBarMetrics.badgeOffset.dx, 0.01));
        expect(delta.dy, closeTo(TabBarMetrics.badgeOffset.dy, 0.01));
      }

      corner(count, find.byIcon(CupertinoIcons.mail));
      corner(empty, find.byIcon(CupertinoIcons.bell));
      corner(text, find.byIcon(CupertinoIcons.gear));
    },
    variant: ios,
  );

  testWidgets('Material: a Material 3 navigation bar, no glass lens', (
    t,
  ) async {
    shaderEnv();
    final picks = <int>[];
    await t.pumpWidget(
      appHost(
        _Harness(
          picks,
          items: const [
            GlassTabBarItem(
              icon: CupertinoIcons.mail,
              label: 'Mail',
              badge: '3',
            ),
            GlassTabBarItem(
              icon: CupertinoIcons.bell,
              label: 'Alerts',
              badge: '',
            ),
            GlassTabBarItem(icon: CupertinoIcons.gear, label: 'Settings'),
          ],
        ),
      ),
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(LiquidGlass), findsNothing);
    expect(find.byType(Badge), findsNWidgets(2));
    expect(find.text('3'), findsOneWidget);
    await t.tap(find.text('Settings'));
    await t.pumpAndSettle();
    expect(picks, [2]);
  }, variant: android);

  testWidgets('the pill defaults to the tab bar fill measured on iOS', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_Harness(_picks())));
    final pill = t.widget<DecoratedBox>(
      find.byWidgetPredicate(
        (w) => w is DecoratedBox && w.decoration is ShapeDecoration,
      ),
    );
    final ctx = t.element(find.byType(GlassTabBar));
    expect(
      (pill.decoration as ShapeDecoration).color!.toARGB32(),
      CupertinoDynamicColor.resolve(GlassColors.tabBarPill, ctx).toARGB32(),
    );
  }, variant: ios);

  testWidgets('the selected tab defaults to the measured tab bar blue', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_Harness(_picks(), selectedColor: null)));
    final ctx = t.element(find.byType(GlassTabBar));
    expect(
      _labelColor(t, 'History')!.toARGB32(),
      CupertinoDynamicColor.resolve(GlassColors.tabBarSelected, ctx).toARGB32(),
    );
  }, variant: ios);

  testWidgets('unselected tabs use the tab bar label colour', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_Harness(_picks())));
    expect(_labelColor(t, 'Snippets')!.toARGB32(), 0xE6000000);
    await t.pumpWidget(
      plainHost(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(platformBrightness: Brightness.dark),
            child: _Harness(_picks()),
          ),
        ),
      ),
    );
    expect(_labelColor(t, 'Snippets')!.toARGB32(), 0xF2FFFFFF);
  }, variant: ios);

  testWidgets('tapping a far tab sends the lens across from the selection', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_Harness(_picks())));
    final history = t.getCenter(find.text('History')).dx;
    final settings = t.getCenter(find.text('Settings')).dx;
    // A device tap: ~100 ms down, then up.
    final g = await t.startGesture(t.getCenter(find.text('Settings')));
    await t.pump(const Duration(milliseconds: 16));
    expect(_lens, findsOneWidget);
    expect(
      t.getCenter(_lens).dx,
      lessThan(history + (settings - history) * 0.3),
      reason: 'the lens starts at the current selection',
    );
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    // Mid-travel, the lens is still shown (it settles only on arrival).
    await t.pump(const Duration(milliseconds: 16));
    expect(_lens, findsOneWidget);
    final mid = t.getCenter(_lens).dx;
    expect(mid, greaterThan(history + (settings - history) * 0.3));
    expect(mid, lessThan(settings - 4));
    // Arrives at ~180 ms (as iOS 26.4 does), then the lens settles.
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(_lens, findsNothing);
  }, variant: ios);

  testWidgets('after a tap the pill settles back to its own size', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_Harness(_picks())));
    // A device tap: ~100 ms down, then real 16-ms frames so the springs
    // and the wobble integrate as on device.
    final g = await t.startGesture(t.getCenter(find.text('Settings')));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    // A quick tap holds the lens for tapHold from touch-down before it
    // settles.
    await t.pump(TabBarMetrics.tapHold);
    for (var i = 0; i < 22; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    final pill = find.byWidgetPredicate(
      (w) => w is DecoratedBox && w.decoration is ShapeDecoration,
    );
    expect(_lens, findsNothing);
    // Back to the pill's 54 pt, give or take the settling squash; no wobble.
    expect(t.getSize(pill).height, moreOrLessEquals(62 - 8, epsilon: 1));
  }, variant: ios);

  testWidgets('after a drag and release no lens is left on the pill', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_Harness(_picks())));
    final from = t.getCenter(find.text('History'));
    final to = t.getCenter(find.text('Settings'));
    final g = await t.startGesture(from);
    for (var i = 0; i < 20; i++) {
      await g.moveTo(Offset.lerp(from, to, i / 19)!);
      await t.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    for (var i = 0; i < 120; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(_lens, findsNothing);
  }, variant: ios);

  testWidgets('only the lens ends refract tabs; its middle and rims do not', (
    t,
  ) async {
    // Without shader support the lens is native glass: the ends-only
    // refraction and the sharp overlay apply.
    GlassPlatform.instance.debugEnvironment = const GlassEnvironment(
      platform: TargetPlatform.iOS,
      iosMajorVersion: 26,
      reduceTransparency: false,
      shaderSupported: false,
    );
    await t.pumpWidget(plainHost(_Harness(_picks())));
    final g = await t.startGesture(t.getCenter(find.text('History')));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    // The tinted copy under the lens glass is clipped to the lens ends.
    final clip = t
        .widgetList<ClipPath>(find.byType(ClipPath))
        .map((c) => c.clipper)
        .whereType<LensEndsClipper>()
        .single;
    final lensBox = t.getRect(_lens);
    final path = clip.getClip(const Size(400, 54));
    final ends = path.getBounds();
    expect(ends.width, greaterThan(lensBox.width * 0.9));
    final middle = Offset(ends.center.dx, ends.center.dy);
    expect(path.contains(middle), isFalse, reason: 'middle is not refracted');
    expect(
      path.contains(Offset(ends.left + 6, ends.center.dy)),
      isTrue,
      reason: 'the leading end is',
    );
    await g.up();
    await t.pumpAndSettle();
  }, variant: ios);

  testWidgets('the sharp copy fades only towards the lens ends', (t) async {
    // Without shader support the lens is native glass: the ends-only
    // refraction and the sharp overlay apply.
    GlassPlatform.instance.debugEnvironment = const GlassEnvironment(
      platform: TargetPlatform.iOS,
      iosMajorVersion: 26,
      reduceTransparency: false,
      shaderSupported: false,
    );
    await t.pumpWidget(plainHost(_Harness(_picks())));
    final g = await t.startGesture(t.getCenter(find.text('History')));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(
      find.descendant(
        of: find.byType(GlassTabBar),
        matching: find.byType(ShaderMask),
      ),
      findsOneWidget,
    );
    await g.up();
    await t.pumpAndSettle();
  }, variant: ios);

  testWidgets('the lens is gone within 8 frames of letting go', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_Harness(_picks())));
    final g = await t.startGesture(t.getCenter(find.text('History')));
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(_lens, findsNothing);
    await t.pumpAndSettle();
  }, variant: ios);

  testWidgets('a quick tap keeps the lens up for tapHold, then settles', (
    t,
  ) async {
    shaderEnv();
    expect(TabBarMetrics.tapHold, const Duration(milliseconds: 200));
    final picks = <int>[];
    await t.pumpWidget(plainHost(_Harness(picks)));
    // A tap on the selected tab: the lens has nowhere to travel, so
    // without the hold it would shrink at once.
    final g = await t.startGesture(t.getCenter(find.text('History')));
    await t.pump(const Duration(milliseconds: 16));
    await g.up();
    // 192 ms after touch-down, still inside tapHold: the lens stays up.
    for (var i = 0; i < 11; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(_lens, findsOneWidget);
    // iOS has settled it into the pill by ~330 ms; so do we.
    for (var i = 0; i < 9; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(_lens, findsNothing);
    expect(picks, isEmpty);
    expect(
      pillX(t),
      moreOrLessEquals(t.getCenter(find.text('History')).dx, epsilon: 1),
    );
    await t.pumpAndSettle();
  }, variant: ios);

  testWidgets('a press held past tapHold releases at once', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_Harness(_picks())));
    final g = await t.startGesture(t.getCenter(find.text('History')));
    // 304 ms, past tapHold: the release is not deferred.
    for (var i = 0; i < 19; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(_lens, findsNothing);
    await t.pumpAndSettle();
  }, variant: ios);

  testWidgets('Reduce Motion: a quick tap does not hold the lens', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: _Harness(_picks()),
          ),
        ),
      ),
    );
    final g = await t.startGesture(t.getCenter(find.text('Settings')));
    await t.pump(const Duration(milliseconds: 16));
    await g.up();
    await t.pump();
    expect(_lens, findsNothing);
    await t.pumpAndSettle();
  }, variant: ios);

  testWidgets('after release the selected tint settles without flickering', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_Harness(_picks())));
    final from = t.getCenter(find.text('History'));
    final to = t.getCenter(find.text('Settings'));
    final g = await t.startGesture(from);
    for (var i = 0; i < 30; i++) {
      await g.moveTo(Offset.lerp(from, to, (i / 20).clamp(0, 1))!);
      await t.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    final tinted = <bool>[];
    for (var i = 0; i < 90; i++) {
      await t.pump(const Duration(milliseconds: 16));
      tinted.add(_labelColor(t, 'Settings') == _blue);
    }
    // Once the tint comes on it stays on: no off/on toggling as the
    // release spring settles.
    final first = tinted.indexOf(true);
    expect(first, isNonNegative);
    expect(tinted.sublist(first), everyElement(isTrue));
  }, variant: ios);

  /// Records the selection haptics the platform is asked for.
  List<String> recordHaptics(WidgetTester t) {
    final calls = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          calls.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return calls;
  }

  Future<void> dragAcross(WidgetTester t) async {
    final from = t.getCenter(find.text('History'));
    final to = t.getCenter(find.text('Settings'));
    final g = await t.startGesture(from);
    await t.pump(const Duration(milliseconds: 100));
    for (var i = 1; i <= 20; i++) {
      await g.moveTo(Offset.lerp(from, to, i / 20)!);
      await t.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await t.pumpAndSettle();
  }

  testWidgets('dragging the lens over each tab ticks once per tab', (t) async {
    shaderEnv();
    final haptics = recordHaptics(t);
    await t.pumpWidget(plainHost(_Harness(_picks())));
    await dragAcross(t);
    // History to Settings crosses Snippets, then lands on Settings.
    expect(haptics, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
    ]);
  }, variant: ios);

  testWidgets('enableFeedback: false keeps the drag silent', (t) async {
    shaderEnv();
    final haptics = recordHaptics(t);
    await t.pumpWidget(plainHost(_Harness(_picks(), enableFeedback: false)));
    await dragAcross(t);
    expect(haptics, isEmpty);
  }, variant: ios);

  testWidgets('a search tab: the bar fills beside a 62 circle', (t) async {
    shaderEnv();
    var searched = 0;
    await t.pumpWidget(
      plainHost(
        SizedBox(
          width: 360,
          child: GlassTabBar(
            items: _items,
            selectedIndex: 0,
            onSelected: (_) {},
            onSearch: () => searched++,
          ),
        ),
      ),
    );
    final circle = t.getRect(find.byType(GlassSearchTabButton));
    expect(circle.size, const Size(62, 62));
    final bar = t.getRect(
      find.descendant(
        of: find.byType(GlassTabBar),
        matching: find.byType(TabBarFillScope),
      ),
    );
    expect(circle.left - bar.right, moreOrLessEquals(8));
    expect(circle.right - bar.left, moreOrLessEquals(360));
    await t.tap(find.byType(GlassSearchTabButton));
    expect(searched, 1);
  }, variant: ios);

  testWidgets(
    "the search tab paints iOS's magnifier: 22.6 square, tab label colour",
    (t) async {
      shaderEnv();
      await t.pumpWidget(
        plainHost(
          SizedBox(
            width: 360,
            child: GlassTabBar(
              items: _items,
              selectedIndex: 0,
              onSelected: (_) {},
              onSearch: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(CupertinoIcons.search), findsNothing);
      final painted = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is SearchGlyph,
      );
      expect(painted, findsOneWidget);
      expect(t.getSize(painted), const Size.square(TabBarMetrics.searchGlyph));
      final circle = t.getCenter(find.byType(GlassSearchTabButton));
      final glyph = t.getCenter(painted);
      expect(glyph.dx, closeTo(circle.dx, 0.01));
      expect(glyph.dy, closeTo(circle.dy, 0.01));
      final painter = t.widget<CustomPaint>(painted).painter as SearchGlyph;
      expect(painter.color, GlassColors.tabBarLabel.color);
    },
    variant: ios,
  );

  testWidgets('shader mode: the search circle has the bar\'s shadow too', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        SizedBox(
          width: 360,
          child: GlassTabBar(
            items: _items,
            selectedIndex: 0,
            onSelected: (_) {},
            onSearch: () {},
            mode: GlassRenderMode.shader,
          ),
        ),
      ),
    );
    final shadows = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is BarShadow,
    );
    expect(shadows, findsNWidgets(2));
    final circle = t.getRect(find.byType(GlassSearchTabButton));
    expect(
      shadows.evaluate().map((e) => t.getRect(find.byWidget(e.widget))),
      contains(circle),
    );
  }, variant: ios);

  group('motion (SwiftUI TabView, iOS 26.4)', () {
    /// The bar's glass, which grows around a held lens.
    double barWidth(WidgetTester t) => t
        .getSize(
          find
              .descendant(
                of: find.byType(GlassTabBar),
                matching: find.byType(LiquidGlass),
              )
              .first,
        )
        .width;

    testWidgets('a quick tap leaves the bar its size', (t) async {
      shaderEnv();
      await t.pumpWidget(plainHost(_Harness(_picks())));
      final rest = barWidth(t);
      final g = await t.startGesture(t.getCenter(find.text('Settings')));
      await g.up();
      var widest = rest;
      for (var i = 0; i < 30; i++) {
        await t.pump(const Duration(milliseconds: 16));
        widest = barWidth(t) > widest ? barWidth(t) : widest;
      }
      expect(widest - rest, lessThan(1));
      await t.pumpAndSettle();
    }, variant: ios);

    testWidgets('a held press grows the bar by growX a side until the lens '
        'settles', (t) async {
      shaderEnv();
      await t.pumpWidget(plainHost(_Harness(_picks())));
      final rest = barWidth(t);
      final g = await t.startGesture(t.getCenter(find.text('History')));
      for (var i = 0; i < 60; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(
        barWidth(t) - rest,
        moreOrLessEquals(2 * TabBarMetrics.growX, epsilon: 0.5),
      );
      await g.up();
      await t.pumpAndSettle();
      expect(barWidth(t), moreOrLessEquals(rest, epsilon: 0.01));
    }, variant: ios);

    testWidgets('a quick tap on another tab never flashes its tint', (t) async {
      shaderEnv();
      await t.pumpWidget(plainHost(_Harness(_picks())));
      final g = await t.startGesture(t.getCenter(find.text('Settings')));
      await g.up();
      await t.pump();
      // The lens is on its way; the tab under it is not tinted yet.
      expect(_labelColor(t, 'Settings'), isNot(_blue));
      await t.pumpAndSettle();
      expect(_labelColor(t, 'Settings'), _blue);
    }, variant: ios);

    testWidgets('a held lens sent to another tab pops, settles on arrival '
        'and lifts again', (t) async {
      shaderEnv();
      await t.pumpWidget(plainHost(_Harness(_picks())));
      final g = await t.startGesture(t.getCenter(find.text('Settings')));
      final heights = <double>[];
      for (var i = 0; i < 60; i++) {
        await t.pump(const Duration(milliseconds: 16));
        heights.add(t.getSize(_lens).height);
      }
      final full = heights.last;
      // Popped up within ~7 frames (iOS: full at frame 6).
      expect(heights[6], greaterThan(full - 4));
      // Down towards the pill after it arrives, then up again.
      final dip = heights.sublist(7, 40).reduce((a, b) => a < b ? a : b);
      expect(dip, lessThan(full - 10));
      await g.up();
      await t.pumpAndSettle();
    }, variant: ios);
  });
}

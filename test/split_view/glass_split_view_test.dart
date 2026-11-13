import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({
  GlassSplitViewController? controller,
  bool three = false,
  GlassRenderMode? mode,
}) => MaterialApp(
  home: GlassSplitView(
    controller: controller,
    mode: mode,
    sidebar: Builder(
      builder: (context) => GestureDetector(
        onTap: () => GlassSplitView.of(context).showColumn(
          three ? GlassSplitViewColumn.content : GlassSplitViewColumn.detail,
        ),
        child: const Text('Side'),
      ),
    ),
    content: three ? const Text('Mid') : null,
    detail: const Text('Detail'),
  ),
);

void _size(WidgetTester t, Size s) {
  t.view.physicalSize = s;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));

  testWidgets('wide: all columns side by side', (t) async {
    _size(t, const Size(1000, 700));
    await t.pumpWidget(_app(three: true));
    final s = t.getRect(find.text('Side')).left;
    final m = t.getRect(find.text('Mid')).left;
    final d = t.getRect(find.text('Detail')).left;
    expect(s, lessThan(m));
    expect(m, lessThan(d));
  });

  testWidgets('wide: detailOnly hides the sidebar, toggle brings it back', (
    t,
  ) async {
    _size(t, const Size(1000, 700));
    final c = GlassSplitViewController();
    await t.pumpWidget(_app(controller: c));
    c.toggleSidebar();
    await t.pumpAndSettle();
    expect(t.getRect(find.text('Detail')).left, lessThan(50));
    expect(find.text('Side', skipOffstage: true), findsNothing);
    c.toggleSidebar();
    await t.pumpAndSettle();
    expect(find.text('Side'), findsOneWidget);
    expect(t.getRect(find.text('Detail')).left, greaterThanOrEqualTo(320));
  });

  testWidgets('compact: shows the sidebar, a tap pushes the detail', (t) async {
    _size(t, const Size(402, 800));
    final c = GlassSplitViewController();
    await t.pumpWidget(_app(controller: c));
    expect(find.text('Detail'), findsNothing);
    await t.tap(find.text('Side'));
    await t.pumpAndSettle();
    expect(c.compactColumn, GlassSplitViewColumn.detail);
    expect(find.text('Detail'), findsOneWidget);
    expect(find.text('Side'), findsNothing);
  });

  testWidgets('compact: back steps to the previous column', (t) async {
    _size(t, const Size(402, 800));
    final c = GlassSplitViewController(
      compactColumn: GlassSplitViewColumn.detail,
    );
    await t.pumpWidget(_app(controller: c, three: true));
    await t.pumpAndSettle();
    expect(find.text('Detail'), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(c.compactColumn, GlassSplitViewColumn.content);
    expect(find.text('Mid'), findsOneWidget);
  });

  testWidgets('material path draws a flat sidebar', (t) async {
    _size(t, const Size(1000, 700));
    await t.pumpWidget(_app(mode: GlassRenderMode.material));
    expect(t.getRect(find.text('Side')).left, lessThan(30));
    expect(find.byType(LiquidGlass), findsNothing);
  });

  testWidgets('glass path: sidebar is inset glass', (t) async {
    _size(t, const Size(1000, 700));
    await t.pumpWidget(_app(mode: GlassRenderMode.shader));
    expect(find.byType(LiquidGlass), findsOneWidget);
  });

  testWidgets('glass: the detail sits 8.33 pt below the top safe area', (
    t,
  ) async {
    _size(t, const Size(1000, 700));
    late EdgeInsets pad;
    await t.pumpWidget(
      MaterialApp(
        home: GlassSplitView(
          mode: GlassRenderMode.shader,
          sidebar: const Text('Side'),
          detail: Builder(
            builder: (context) {
              pad = MediaQuery.paddingOf(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    // Measured: SwiftUI's detail title is centred 31.5 pt down, 8.3 below a
    // bar at the top (gap-split-swiftui.png).
    expect(pad.top, moreOrLessEquals(8.33, epsilon: 0.01));
  });

  testWidgets('sidebar button: toolbar-sized glyph, toggles the sidebar', (
    t,
  ) async {
    _size(t, const Size(1000, 700));
    final c = GlassSplitViewController();
    addTearDown(c.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: GlassSplitView(
          controller: c,
          mode: GlassRenderMode.shader,
          sidebar: const Align(
            alignment: Alignment.topRight,
            child: GlassSplitViewSidebarButton(mode: GlassRenderMode.shader),
          ),
          detail: const Text('Detail'),
        ),
      ),
    );
    await t.pumpAndSettle();
    // A bar item's 26-pt icon: SwiftUI's glyph is ~24.5 x 19 pt of ink.
    final icon = t.widget<Icon>(find.byIcon(CupertinoIcons.sidebar_left));
    expect(icon.size ?? IconTheme.of(t.element(find.byType(Icon))).size, 26);
    expect(find.bySemanticsLabel('Hide Sidebar'), findsOneWidget);
    await t.tap(find.byType(GlassSplitViewSidebarButton));
    await t.pumpAndSettle();
    expect(c.visibility, GlassSplitViewVisibility.detailOnly);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}

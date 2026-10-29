import 'dart:async';

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/tab_bar/native_system_tab_bar.dart';
import 'package:adaptive_liquid_glass/src/tab_bar/native_tab_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

List<GlassTabBarItem> symbols() => [
  GlassTabBarItem.symbol(
    'house',
    activeSymbol: 'house.fill',
    fallback: CupertinoIcons.house,
    label: 'Home',
  ),
  GlassTabBarItem.symbol(
    'music.note',
    fallback: CupertinoIcons.music_note,
    label: 'Music',
    badge: '2',
  ),
];

void _ignorePick(int index) {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('packages/cupertino_icons/CupertinoIcons')
      ..addFont(
        rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
      );
    await loader.load();
  });
  test('native metadata preserves SF symbols, selected artwork and badges', () {
    final items = nativeTabItems(symbols())!;
    expect(
      items[0],
      const NativeTabItem(
        label: 'Home',
        symbol: 'house',
        activeSymbol: 'house.fill',
        badge: null,
      ),
    );
    expect(items[1].badge, '2');
  });
  test('native metadata preserves bundled normal and selected icons', () {
    final items = nativeTabItems(const [
      GlassTabBarItem(
        icon: CupertinoIcons.house,
        activeIcon: CupertinoIcons.house_fill,
        label: 'Home',
        badge: '3',
      ),
      GlassTabBarItem(
        icon: IconData(0xe88a, fontFamily: 'MaterialIcons'),
        label: 'Material',
      ),
    ])!;
    expect(
      items.first,
      const NativeTabItem(
        label: 'Home',
        icon: CupertinoIcons.house,
        activeIcon: CupertinoIcons.house_fill,
        badge: '3',
      ),
    );
    expect(items.last.icon!.fontFamily, 'MaterialIcons');
  });
  test('custom fonts, widgets and spacers keep Flutter rendering', () {
    for (final item in [
      const GlassTabBarItem(
        icon: IconData(0x41, fontFamily: 'Custom'),
        label: 'Custom',
      ),
      const GlassTabBarItem(
        icon: CupertinoIcons.house,
        activeIcon: IconData(0x41, fontFamily: 'Custom'),
        label: 'Custom selected',
      ),
      const GlassTabBarItem.custom(iconWidget: Text('custom'), label: 'Custom'),
      const GlassTabBarItem.spacer(),
    ]) {
      expect(nativeTabItems([symbols().first, item]), isNull);
    }
  });

  test('native metadata preserves empty dot badges on symbols and icons', () {
    final items = nativeTabItems([
      GlassTabBarItem.symbol(
        'house',
        fallback: CupertinoIcons.house,
        label: 'Home',
        badge: '',
      ),
      const GlassTabBarItem(
        icon: CupertinoIcons.music_note,
        label: 'Music',
        badge: '',
      ),
    ]);
    expect(items, isNotNull);
    expect(items!.map((item) => item.badge), ['', '']);
  });

  testWidgets('bundled templates are prepared once and reused for selection', (
    t,
  ) async {
    final messenger = t.binding.defaultBinaryMessenger;
    final creates = <Map<Object?, Object?>>[];
    final updates = <Map<Object?, Object?>>[];
    MethodChannel? native;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method != 'create') return null;
      final args = call.arguments as Map;
      final bytes = args['params'] as Uint8List;
      creates.add(
        const StandardMessageCodec().decodeMessage(ByteData.sublistView(bytes))
            as Map,
      );
      final id = args['id'] as int;
      native = MethodChannel('adaptive_liquid_glass/native_tabs_$id');
      messenger.setMockMethodCallHandler(native!, (call) async {
        if (call.method == 'update') updates.add(call.arguments as Map);
        return true;
      });
      return id;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      if (native != null) messenger.setMockMethodCallHandler(native!, null);
    });
    const entries = [
      NativeTabItem(
        label: 'Home',
        icon: CupertinoIcons.house,
        activeIcon: CupertinoIcons.house_fill,
      ),
      NativeTabItem(label: 'Music', icon: CupertinoIcons.music_note),
    ];
    Widget host(int selected) => MediaQuery(
      data: const MediaQueryData(devicePixelRatio: 3),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: NativeSystemTabBar(
            items: entries,
            selectedIndex: selected,
            onSelected: (_) {},
            tint: null,
            dark: false,
            width: 188,
            height: 62,
            fallback: const Text('loading'),
          ),
        ),
      ),
    );
    await t.pumpWidget(host(0));
    expect(find.text('loading'), findsOneWidget);
    expect(creates, isEmpty);
    for (var i = 0; i < 20 && find.byType(UiKitView).evaluate().isEmpty; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump();
    }
    await t.pumpAndSettle();
    expect(creates, hasLength(1));
    expect(creates.single['imageScale'], 3);
    final first = (creates.single['items'] as List).first as Map;
    final image = first['image'] as Uint8List;
    final active = first['activeImage'] as Uint8List;
    expect(image.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(ByteData.sublistView(image).getUint32(16), 84);
    expect(ByteData.sublistView(image).getUint32(20), 84);
    expect(active, isNot(orderedEquals(image)));
    Map<Object?, Object?> firstItem() =>
        ((t.widget<UiKitView>(find.byType(UiKitView)).creationParams
                        as Map)['items']
                    as List)
                .first
            as Map;
    final cachedImage = firstItem()['image'];
    final cachedActive = firstItem()['activeImage'];
    updates.clear();
    await t.pumpWidget(host(1));
    await t.pumpAndSettle();
    expect(creates, hasLength(1));
    expect(identical(firstItem()['image'], cachedImage), isTrue);
    expect(identical(firstItem()['activeImage'], cachedActive), isTrue);
    expect(updates.last['selectedIndex'], 1);
    final updatedFirst = (updates.last['items'] as List).first as Map;
    expect(updatedFirst['image'], orderedEquals(image));
    expect(updatedFirst['activeImage'], orderedEquals(active));
  }, variant: ios);

  testWidgets('latest icon, scale and direction win while images load', (
    t,
  ) async {
    final messenger = t.binding.defaultBinaryMessenger;
    final creates = <Map<Object?, Object?>>[];
    MethodChannel? native;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method != 'create') return null;
      final args = call.arguments as Map;
      creates.add(
        const StandardMessageCodec().decodeMessage(
              ByteData.sublistView(args['params'] as Uint8List),
            )
            as Map,
      );
      native = MethodChannel('adaptive_liquid_glass/native_tabs_${args['id']}');
      messenger.setMockMethodCallHandler(native!, (_) async => true);
      return args['id'];
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      if (native != null) messenger.setMockMethodCallHandler(native!, null);
    });
    Widget host(IconData icon, double ratio, TextDirection direction) =>
        MediaQuery(
          data: MediaQueryData(devicePixelRatio: ratio),
          child: Directionality(
            textDirection: direction,
            child: Center(
              child: NativeSystemTabBar(
                items: [NativeTabItem(label: 'Latest', icon: icon)],
                selectedIndex: 0,
                onSelected: _ignorePick,
                tint: null,
                dark: false,
                width: 188,
                height: 62,
                fallback: const Text('loading'),
              ),
            ),
          ),
        );
    await t.pumpWidget(host(CupertinoIcons.house, 3, TextDirection.ltr));
    expect(find.text('loading'), findsOneWidget);
    await t.pumpWidget(host(CupertinoIcons.arrow_left, 2, TextDirection.rtl));
    for (var i = 0; i < 30 && find.byType(UiKitView).evaluate().isEmpty; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump();
    }
    await t.pumpAndSettle();
    expect(creates, hasLength(1));
    expect(creates.single['imageScale'], 2);
    expect(creates.single['rtl'], true);
    final item = (creates.single['items'] as List).single as Map;
    final png = item['image'] as Uint8List;
    expect(ByteData.sublistView(png).getUint32(16), 56);
    final expected = await t.runAsync(
      () => rasterizeNativeTabIcon(
        CupertinoIcons.arrow_left,
        pixelRatio: 2,
        textDirection: TextDirection.rtl,
      ),
    );
    expect(png, orderedEquals(expected!));
  }, variant: ios);

  testWidgets('disposing during icon preparation creates no native view', (
    t,
  ) async {
    final messenger = t.binding.defaultBinaryMessenger;
    var creates = 0;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') creates++;
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        null,
      ),
    );
    await t.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(devicePixelRatio: 3),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: NativeSystemTabBar(
            items: [
              NativeTabItem(
                label: 'Home',
                icon: CupertinoIcons.house,
                activeIcon: CupertinoIcons.house_fill,
              ),
            ],
            selectedIndex: 0,
            onSelected: _ignorePick,
            tint: null,
            dark: false,
            width: 188,
            height: 62,
            fallback: Text('loading'),
          ),
        ),
      ),
    );
    expect(find.byType(UiKitView), findsNothing);
    await t.pumpWidget(const SizedBox.shrink());
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pumpAndSettle();
    expect(creates, 0);
    expect(t.takeException(), isNull);
  }, variant: ios);

  testWidgets(
    'native picks suppress reselect and preserve controlled selection',
    (t) async {
      final messenger = t.binding.defaultBinaryMessenger;
      MethodChannel? native;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method != 'create') return null;
        final id = (call.arguments as Map)['id'] as int;
        native = MethodChannel('adaptive_liquid_glass/native_tabs_$id');
        messenger.setMockMethodCallHandler(native!, (call) async => true);
        return id;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        if (native != null) messenger.setMockMethodCallHandler(native!, null);
      });
      final picks = <int>[];
      var selected = 0;
      var acceptsPicks = true;
      await t.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: StatefulBuilder(
              builder: (context, setState) => NativeSystemTabBar(
                items: nativeTabItems(symbols())!,
                selectedIndex: selected,
                onSelected: (index) {
                  picks.add(index);
                  if (acceptsPicks) setState(() => selected = index);
                },
                tint: null,
                dark: false,
                width: 188,
                height: 62,
                fallback: const Text('fallback'),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      Future<Object?> pick(int index) async {
        const codec = StandardMethodCodec();
        final response = Completer<Object?>();
        t.binding.channelBuffers.push(
          native!.name,
          codec.encodeMethodCall(MethodCall('selected', index)),
          (data) => response.complete(codec.decodeEnvelope(data!)),
        );
        await t.pump();
        return response.future;
      }

      expect(await pick(0), 0);
      expect(picks, isEmpty);
      expect(await pick(1), 1);
      expect(picks, [1]);
      expect(await pick(1), 1);
      expect(picks, [1]);
      acceptsPicks = false;
      expect(await pick(0), 1);
      expect(picks, [1, 0]);
      expect(await pick(-1), 1);
      expect(await pick(2), 1);
      expect(picks, [1, 0]);
    },
    variant: ios,
  );

  testWidgets('Flutter overlay excludes native tabs from its hit test', (
    t,
  ) async {
    final messenger = t.binding.defaultBinaryMessenger;
    MethodChannel? native;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method != 'create') return null;
      final id = (call.arguments as Map)['id'] as int;
      native = MethodChannel('adaptive_liquid_glass/native_tabs_$id');
      messenger.setMockMethodCallHandler(native!, (call) async => true);
      return id;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      if (native != null) messenger.setMockMethodCallHandler(native!, null);
    });
    var overlayTaps = 0;
    const overlay = Key('overlay');
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 188,
            height: 62,
            child: Stack(
              children: [
                NativeSystemTabBar(
                  items: nativeTabItems(symbols())!,
                  selectedIndex: 0,
                  onSelected: (_) {},
                  tint: null,
                  dark: false,
                  width: 188,
                  height: 62,
                  fallback: const Text('fallback'),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  width: 86,
                  height: 62,
                  child: GestureDetector(
                    key: overlay,
                    behavior: HitTestBehavior.opaque,
                    onTap: () => overlayTaps++,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final blockedPoint = t.getCenter(find.byKey(overlay));
    final exposedPoint = blockedPoint + const Offset(94, 0);
    bool hitsNative(Offset point) => t
        .hitTestOnBinding(point)
        .path
        .any((entry) => entry.target is RenderUiKitView);
    expect(hitsNative(exposedPoint), isTrue);
    expect(hitsNative(blockedPoint), isFalse);
    await t.tap(find.byKey(overlay));
    await t.pump();
    expect(overlayTaps, 1);
  }, variant: ios);

  testWidgets('native tabs wait for route entrance and detach on reverse', (
    t,
  ) async {
    t.view.physicalSize = const Size(402, 874);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    GlassProgram.instance.debugReset(skipLoad: true);
    GlassPlatform.instance.debugEnvironment = const GlassEnvironment(
      platform: TargetPlatform.iOS,
      iosMajorVersion: 26,
      reduceTransparency: false,
      shaderSupported: true,
    );
    addTearDown(() => GlassPlatform.instance.debugReset());
    final messenger = t.binding.defaultBinaryMessenger;
    final channels = <MethodChannel>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method != 'create') return null;
      final args = call.arguments as Map;
      final id = args['id'] as int;
      final kind = (args['viewType'] as String).endsWith('native_tabs')
          ? 'native_tabs'
          : 'native_glass';
      final channel = MethodChannel('adaptive_liquid_glass/${kind}_$id');
      channels.add(channel);
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'update' ? true : null,
      );
      return id;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (final channel in channels) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });
    final navigator = GlobalKey<NavigatorState>();
    await t.pumpWidget(
      CupertinoApp(navigatorKey: navigator, home: const Text('home')),
    );
    await t.pumpAndSettle();
    final route = PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, _, _) => Align(
        alignment: Alignment.bottomCenter,
        child: GlassTabBar(
          items: symbols(),
          selectedIndex: 0,
          onSelected: (_) {},
          mode: GlassRenderMode.native,
        ),
      ),
      transitionsBuilder: (_, animation, _, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
    unawaited(navigator.currentState!.push(route));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(route.animation!.status, AnimationStatus.forward);
    expect(find.byType(GlassTabBar), findsOneWidget);
    expect(find.byType(NativeSystemTabBar), findsNothing);
    await t.pumpAndSettle();
    expect(route.animation!.status, AnimationStatus.completed);
    expect(find.byType(NativeSystemTabBar), findsOneWidget);
    navigator.currentState!.pop();
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(route.animation!.status, AnimationStatus.reverse);
    expect(find.byType(GlassTabBar), findsOneWidget);
    expect(find.byType(NativeSystemTabBar), findsNothing);
    await t.pumpAndSettle();
    expect(find.byType(GlassTabBar), findsNothing);
  }, variant: ios);

  testWidgets('Flutter bar keeps its state when the entrance hands off', (
    t,
  ) async {
    t.view.physicalSize = const Size(402, 874);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    GlassProgram.instance.debugReset(skipLoad: true);
    GlassPlatform.instance.debugEnvironment = const GlassEnvironment(
      platform: TargetPlatform.iOS,
      iosMajorVersion: 26,
      reduceTransparency: false,
      shaderSupported: true,
    );
    addTearDown(() => GlassPlatform.instance.debugReset());
    final navigator = GlobalKey<NavigatorState>();
    await t.pumpWidget(
      CupertinoApp(navigatorKey: navigator, home: const Text('home')),
    );
    await t.pumpAndSettle();
    final route = PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, _, _) => Align(
        alignment: Alignment.bottomCenter,
        child: GlassTabBar(
          // Bundled icons render to PNGs first, so the native bar shows
          // its Flutter fallback right after the entrance completes.
          items: const [
            GlassTabBarItem(icon: CupertinoIcons.house, label: 'Home'),
            GlassTabBarItem(icon: CupertinoIcons.music_note, label: 'Music'),
          ],
          selectedIndex: 0,
          onSelected: _ignorePick,
          mode: GlassRenderMode.native,
        ),
      ),
    );
    unawaited(navigator.currentState!.push(route));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    State<StatefulWidget> barState() => t.state(
      find
          .descendant(
            of: find.byType(GlassTabBar),
            matching: find.byType(RawGestureDetector),
          )
          .first,
    );
    final before = barState();
    await t.pump(const Duration(milliseconds: 400));
    expect(route.animation!.status, AnimationStatus.completed);
    expect(find.byType(NativeSystemTabBar), findsOneWidget);
    expect(barState(), same(before));
  }, variant: ios);

  for (final customization in [
    'stock',
    'dot-badge',
    'custom-height',
    'search',
    'reduced-motion',
    'custom-material',
  ]) {
    testWidgets('native system control eligibility: $customization', (t) async {
      t.view.physicalSize = const Size(402, 874);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      GlassProgram.instance.debugReset(skipLoad: true);
      GlassPlatform.instance.debugEnvironment = const GlassEnvironment(
        platform: TargetPlatform.iOS,
        iosMajorVersion: 26,
        reduceTransparency: false,
        shaderSupported: true,
      );
      addTearDown(() => GlassPlatform.instance.debugReset());
      final channels = <MethodChannel>[];
      final messenger = t.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method != 'create') return null;
        final args = call.arguments as Map;
        final id = args['id'] as int;
        final kind = (args['viewType'] as String).endsWith('native_tabs')
            ? 'native_tabs'
            : 'native_glass';
        final channel = MethodChannel('adaptive_liquid_glass/${kind}_$id');
        channels.add(channel);
        messenger.setMockMethodCallHandler(
          channel,
          (call) async => call.method == 'update' ? true : null,
        );
        return id;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in channels) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });
      final bar = GlassTabBar(
        items: customization == 'dot-badge'
            ? [
                GlassTabBarItem.symbol(
                  'house',
                  fallback: CupertinoIcons.house,
                  label: 'Home',
                  badge: '',
                ),
                symbols().last,
              ]
            : symbols(),
        selectedIndex: 0,
        onSelected: (_) {},
        mode: GlassRenderMode.native,
        height: customization == 'custom-height' ? 70 : 62,
        glass: customization == 'custom-material' ? Glass.clear : null,
        onSearch: customization == 'search' ? () {} : null,
      );
      await t.pumpWidget(
        plainHost(
          MediaQuery(
            data: MediaQueryData(
              size: const Size(402, 874),
              disableAnimations: customization == 'reduced-motion',
            ),
            child: bar,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.byType(NativeSystemTabBar),
        customization == 'stock' || customization == 'dot-badge'
            ? findsOneWidget
            : findsNothing,
      );
    }, variant: ios);
  }
}

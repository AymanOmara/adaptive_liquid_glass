import 'dart:async';
import 'dart:ui' as ui;

import 'package:adaptive_liquid_glass/src/color_picker/app_capture.dart';
import 'package:adaptive_liquid_glass/src/tab_bar/native_system_tab_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const items = <NativeTabItem>[
  NativeTabItem(
    label: 'Home',
    symbol: 'house.fill',
    activeSymbol: null,
    badge: null,
  ),
  NativeTabItem(
    label: 'Music',
    symbol: 'music.note',
    activeSymbol: null,
    badge: null,
  ),
  NativeTabItem(
    label: 'Settings',
    symbol: 'gearshape.fill',
    activeSymbol: null,
    badge: '2',
  ),
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native tabs preserve selection, re-theme and recover from invalid symbols',
    (t) async {
      if (defaultTargetPlatform != TargetPlatform.iOS) return;
      const plugin = MethodChannel('adaptive_liquid_glass');
      Future<int?> hostCount() =>
          plugin.invokeMethod<int>('debugNativeTabHosts');
      expect(await hostCount(), 0);
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      final dark = ValueNotifier(false);
      addTearDown(dark.dispose);
      var acceptsPicks = true;
      Widget host(List<NativeTabItem> entries) => MaterialApp(
        home: ColoredBox(
          color: const Color(0xFFFF0000),
          child: Stack(
            children: [
              Positioned(
                left: 64,
                top: 790,
                child: ListenableBuilder(
                  listenable: Listenable.merge([selected, dark]),
                  builder: (_, _) => NativeSystemTabBar(
                    items: entries,
                    selectedIndex: selected.value,
                    onSelected: (i) {
                      if (acceptsPicks) selected.value = i;
                    },
                    tint: const Color(0xFF007AFF),
                    dark: dark.value,
                    width: 274,
                    height: 62,
                    fallback: const Text('fallback'),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      Future<void> settle() async {
        for (var i = 0; i < 5; i++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await t.pump();
        }
      }

      await t.pumpWidget(host(items));
      await settle();
      final id = t.allRenderObjects
          .whereType<RenderUiKitView>()
          .single
          .viewController
          .id;
      final channel = MethodChannel('adaptive_liquid_glass/native_tabs_$id');
      Future<Map<Object?, Object?>> state() async =>
          (await channel.invokeMapMethod<Object?, Object?>('debugState'))!;
      var s = await state();
      expect(s['visible'], true);
      expect(s['attached'], true);
      expect(s['contained'], true);
      expect(await hostCount(), 1);
      expect(s['items'], 3);
      expect(s['selectedIndex'], 0);
      await channel.invokeMethod<void>('debugSelect', 1);
      await settle();
      expect(selected.value, 1);
      expect((await state())['selectedIndex'], 1);
      acceptsPicks = false;
      await channel.invokeMethod<void>('debugSelect', 2);
      await settle();
      expect(selected.value, 1);
      expect((await state())['selectedIndex'], 1);
      dark.value = true;
      await settle();
      s = await state();
      expect(s['dark'], true);
      expect(s['visible'], true);
      expect(s['selectedIndex'], 1);
      dark.value = false;
      await settle();
      expect((await state())['dark'], false);
      expect(await hostCount(), 1);
      // A selection acknowledgment can arrive after a newer app update.
      // It must not replace that update's selected index.
      final ack = Completer<int>();
      final picked = Completer<void>();
      channel.setMethodCallHandler((call) async {
        if (call.method == 'selected') {
          picked.complete();
          return ack.future;
        }
        return null;
      });
      await channel.invokeMethod<void>('debugSelect', 0);
      await picked.future;
      await channel.invokeMethod<bool>('update', {
        'items': [
          for (final item in items)
            {'label': item.label, 'symbol': item.symbol, 'badge': item.badge},
        ],
        'selectedIndex': 2,
        'dark': false,
        'overhang': 24.0,
      });
      ack.complete(0);
      await settle();
      expect((await state())['selectedIndex'], 2);
      // Unknown SF Symbols keep the existing Flutter rendering and its fallback.
      await t.pumpWidget(
        host([
          NativeTabItem(
            label: 'Missing',
            symbol: 'not.a.real.symbol',
            activeSymbol: null,
            badge: null,
          ),
          items[1],
        ]),
      );
      await settle();
      expect(find.text('fallback'), findsOneWidget);
      expect(await hostCount(), 0);
      await t.pumpWidget(host(items));
      await settle();
      expect(find.text('fallback'), findsNothing);
      expect(await hostCount(), 1);
      await t.pumpWidget(const SizedBox.shrink());
      await settle();
      expect(find.byType(UiKitView), findsNothing);
      expect(await hostCount(), 0);
    },
  );
  testWidgets('system capsules fit two, three and four Flutter tab slots', (
    t,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    for (final count in [2, 3, 4]) {
      final width = (count * 86 + 16).toDouble();
      final entries = [
        ...items,
        NativeTabItem(
          label: 'A very long tab label',
          symbol: 'star.fill',
          activeSymbol: null,
          badge: null,
        ),
      ].take(count).toList();
      await t.pumpWidget(
        MaterialApp(
          home: ColoredBox(
            color: const Color(0xFFFF0000),
            child: Stack(
              children: [
                Positioned(
                  left: (402 - width) / 2,
                  top: 790,
                  child: NativeSystemTabBar(
                    key: ValueKey(count),
                    items: entries,
                    selectedIndex: 0,
                    onSelected: (_) {},
                    tint: null,
                    dark: false,
                    width: width,
                    height: 62,
                    fallback: const Text('fallback'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await t.pump();
      }
      expect(find.text('fallback'), findsNothing);
      final capture = await t.runAsync(() => captureAppView(t.view));
      expect(capture, isNotNull);
      final image = capture!.image;
      final bytes = await t.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      final row = (821 * capture.ratio).round();
      final xs = <int>[];
      for (var x = 0; x < image.width; x++) {
        final offset = (row * image.width + x) * 4;
        if (bytes!.getUint8(offset + 1) > 12 ||
            bytes.getUint8(offset + 2) > 12) {
          xs.add(x);
        }
      }
      image.dispose();
      expect(xs, isNotEmpty);
      expect(
        xs.first / capture.ratio,
        closeTo((402 - width) / 2, 2),
        reason: '$count tabs left',
      );
      expect(
        (xs.last + 1) / capture.ratio,
        closeTo((402 + width) / 2, 2),
        reason: '$count tabs right',
      );
    }
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  });
  testWidgets('bundled icons decode at logical size and reuse native items', (
    t,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: ColoredBox(
          color: const Color(0xFFFF0000),
          child: Stack(
            children: [
              Positioned(
                left: 107,
                top: 790,
                child: ValueListenableBuilder<int>(
                  valueListenable: selected,
                  builder: (_, value, _) => NativeSystemTabBar(
                    items: const [
                      NativeTabItem(
                        label: 'Home',
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home,
                      ),
                      NativeTabItem(label: 'Music', icon: Icons.music_note),
                    ],
                    selectedIndex: value,
                    onSelected: (i) => selected.value = i,
                    tint: null,
                    dark: false,
                    width: 188,
                    height: 62,
                    fallback: const Text('loading'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 12; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await t.pump();
      }
    }

    await settle();
    expect(find.text('loading'), findsNothing);
    final id = t.allRenderObjects
        .whereType<RenderUiKitView>()
        .single
        .viewController
        .id;
    final channel = MethodChannel('adaptive_liquid_glass/native_tabs_$id');
    Future<Map<Object?, Object?>> state() async =>
        (await channel.invokeMapMethod<Object?, Object?>('debugState'))!;
    var s = await state();
    expect(s['imageWidths'], [28.0, 28.0]);
    expect(s['activeImageWidths'], [28.0, 28.0]);
    expect(s['templateCount'], 3);
    final revision = s['itemRevision'];
    await channel.invokeMethod<void>('debugSelect', 1);
    await settle();
    expect(selected.value, 1);
    s = await state();
    expect(s['selectedIndex'], 1);
    expect(s['templateCount'], 3);
    expect(s['itemRevision'], revision);
    await t.pumpWidget(const SizedBox.shrink());
    await settle();
    expect(
      await const MethodChannel('adaptive_liquid_glass')
          .invokeMethod<int>('debugNativeTabHosts'),
      0,
    );
  });
}

import 'dart:ui' as ui;

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/color_picker/app_capture.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native dot badges update and clear in both appearances', (
    t,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    final badge = ValueNotifier<String?>('');
    final dark = ValueNotifier(false);
    final selected = ValueNotifier(0);
    final bitmap = ValueNotifier(false);
    addTearDown(badge.dispose);
    addTearDown(dark.dispose);
    addTearDown(selected.dispose);
    addTearDown(bitmap.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: Listenable.merge([badge, dark, selected, bitmap]),
          builder: (context, _) => ColoredBox(
            color: dark.value ? Colors.black : Colors.white,
            child: Stack(
              children: [
                Positioned(
                  left: 107,
                  top: 790,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      platformBrightness: dark.value
                          ? Brightness.dark
                          : Brightness.light,
                    ),
                    child: GlassTabBar(
                      items: bitmap.value
                          ? [
                              GlassTabBarItem(
                                icon: Icons.home,
                                activeIcon: Icons.home_outlined,
                                label: 'Home',
                                badge: badge.value,
                              ),
                              const GlassTabBarItem(
                                icon: Icons.music_note,
                                label: 'Music',
                              ),
                            ]
                          : [
                              GlassTabBarItem.symbol(
                                'house.fill',
                                fallback: Icons.home,
                                label: 'Home',
                                badge: badge.value,
                              ),
                              GlassTabBarItem.symbol(
                                'music.note',
                                fallback: Icons.music_note,
                                label: 'Music',
                              ),
                            ],
                      selectedIndex: selected.value,
                      onSelected: (i) => selected.value = i,
                      mode: GlassRenderMode.native,
                    ),
                  ),
                ),
              ],
            ),
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
      expect(find.text('fallback'), findsNothing);
      expect(find.byType(UiKitView), findsOneWidget);
    }

    Future<({double width, double height, double area})> redBadge() async {
      final capture = await t.runAsync(() => captureAppView(t.view));
      expect(capture, isNotNull);
      final image = capture!.image;
      try {
        final bytes = await t.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        var minX = image.width;
        var minY = image.height;
        var maxX = -1;
        var maxY = -1;
        var count = 0;
        // This region contains both native tabs and no other red content.
        for (
          var y = (780 * capture.ratio).round();
          y < (854 * capture.ratio).round();
          y++
        ) {
          for (
            var x = (107 * capture.ratio).round();
            x < (295 * capture.ratio).round();
            x++
          ) {
            final offset = (y * image.width + x) * 4;
            if (bytes!.getUint8(offset) > 150 &&
                bytes.getUint8(offset + 1) < 110 &&
                bytes.getUint8(offset + 2) < 110) {
              if (x < minX) minX = x;
              if (y < minY) minY = y;
              if (x > maxX) maxX = x;
              if (y > maxY) maxY = y;
              count++;
            }
          }
        }
        return (
          width: count == 0 ? 0.0 : (maxX - minX + 1) / capture.ratio,
          height: count == 0 ? 0.0 : (maxY - minY + 1) / capture.ratio,
          area: count / (capture.ratio * capture.ratio),
        );
      } finally {
        image.dispose();
      }
    }

    for (final scene in [
      (bitmap: false, dark: false),
      (bitmap: false, dark: true),
      (bitmap: true, dark: false),
      (bitmap: true, dark: true),
    ]) {
      dark.value = scene.dark;
      bitmap.value = scene.bitmap;
      badge.value = '';
      await settle();
      final dot = await redBadge();
      debugPrint('NATIVE_DOT_BADGE $scene $dot');
      expect(dot.width, closeTo(18, 2));
      expect(dot.height, closeTo(18, 2));
      expect(dot.area, greaterThan(150));
      final id = t.allRenderObjects
          .whereType<RenderUiKitView>()
          .single
          .viewController
          .id;
      final channel = MethodChannel('adaptive_liquid_glass/native_tabs_$id');
      await channel.invokeMethod<void>('debugSelect', 1);
      await settle();
      expect(selected.value, 1);
      final unselectedDot = await redBadge();
      expect(unselectedDot.width, closeTo(dot.width, 1));
      expect(unselectedDot.height, closeTo(dot.height, 1));
      badge.value = '22';
      await settle();
      final count = await redBadge();
      expect(count.width, greaterThan(dot.width));
      badge.value = null;
      await settle();
      expect((await redBadge()).area, 0);
      selected.value = 0;
    }
    await t.pumpWidget(const SizedBox.shrink());
    await settleAfterRemoval(t);
  });
}

Future<void> settleAfterRemoval(WidgetTester t) async {
  await t.pumpAndSettle();
  expect(
    await const MethodChannel('adaptive_liquid_glass')
        .invokeMethod<int>('debugNativeTabHosts'),
    0,
  );
}

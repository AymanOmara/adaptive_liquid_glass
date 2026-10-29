import 'package:adaptive_liquid_glass/src/tab_bar/native_system_tab_bar.dart';
import 'package:adaptive_liquid_glass/src/tab_bar/native_tab_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

void main() {
  testWidgets('late font load replaces cached native templates', (t) async {
    final messenger = t.binding.defaultBinaryMessenger;
    final channels = <MethodChannel>[];
    final creates = <Map<Object?, Object?>>[];
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
      final channel = MethodChannel(
        'adaptive_liquid_glass/native_tabs_${args['id']}',
      );
      channels.add(channel);
      messenger.setMockMethodCallHandler(channel, (_) async => true);
      return args['id'];
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (final channel in channels) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });
    await t.pumpWidget(
      plainHost(
        NativeSystemTabBar(
          items: const [
            NativeTabItem(label: 'Home', icon: CupertinoIcons.house),
          ],
          selectedIndex: 0,
          onSelected: (_) {},
          tint: null,
          dark: false,
          width: 188,
          height: 62,
          fallback: const Text('loading'),
        ),
      ),
    );
    Future<void> finishImages() async {
      for (
        var i = 0;
        i < 50 && find.byType(UiKitView).evaluate().isEmpty;
        i++
      ) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await t.pump();
      }
      await t.pumpAndSettle();
      expect(find.byType(UiKitView), findsOneWidget);
    }

    Uint8List image(Map<Object?, Object?> params) =>
        ((params['items'] as List).first as Map)['image'] as Uint8List;
    await finishImages();
    final before = image(creates.single);
    await t.runAsync(() async {
      final loader = FontLoader('packages/cupertino_icons/CupertinoIcons')
        ..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        );
      await loader.load();
    });
    await t.pump();
    await finishImages();
    expect(creates, hasLength(2));
    final refreshed = image(creates.last);
    expect(refreshed, isNot(orderedEquals(before)));
    final expected = await t.runAsync(
      () => rasterizeNativeTabIcon(
        CupertinoIcons.house,
        pixelRatio: t.view.devicePixelRatio,
        textDirection: TextDirection.ltr,
      ),
    );
    expect(refreshed, orderedEquals(expected!));

    // A second notification while an image is pending must supersede it.
    await t.binding.handleSystemMessage({'type': 'fontsChange'});
    await t.binding.handleSystemMessage({'type': 'fontsChange'});
    await t.pump();
    await finishImages();
    expect(creates, hasLength(3));
    expect(image(creates.last), orderedEquals(expected));

    // Disposing during another refresh invalidates the pending images and
    // removes the font listener.
    await t.binding.handleSystemMessage({'type': 'fontsChange'});
    await t.pumpWidget(const SizedBox());
    await t.binding.handleSystemMessage({'type': 'fontsChange'});
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(creates, hasLength(3));
  }, variant: ios);
}

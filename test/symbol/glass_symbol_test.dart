import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('off iOS a symbol shows its fallback icon', (t) async {
    await t.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: GlassSymbol('house.fill', fallback: CupertinoIcons.house_fill),
      ),
    );
    expect(find.byIcon(CupertinoIcons.house_fill), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('on iOS an unknown symbol keeps its fallback', (t) async {
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('adaptive_liquid_glass'),
      (call) async => call.method == 'symbol' ? null : <String, Object?>{},
    );
    await t.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: GlassSymbol('no.such.symbol', fallback: CupertinoIcons.gear),
      ),
    );
    await t.pump();
    expect(find.byIcon(CupertinoIcons.gear), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a symbol tab item keeps its label', (t) async {
    final item = GlassTabBarItem.symbol(
      'music.note',
      fallback: CupertinoIcons.music_note,
      label: 'Music',
    );
    expect(item.label, 'Music');
    expect(item.iconWidget, isNotNull);
    expect(item.icon, isNull);
  });
}

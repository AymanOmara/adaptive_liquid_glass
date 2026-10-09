import 'package:adaptive_liquid_glass_example/quick_start.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'the quick start builds, switches tabs and opens a sheet',
    (t) async {
      await t.pumpWidget(const QuickStartApp());
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Hello, glass'), findsOneWidget);

      await t.tap(find.text('Alerts'));
      await t.pump(const Duration(seconds: 1));

      await t.tap(find.text('Open a sheet'));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Drag between detents'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant(const {
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}

import 'package:adaptive_liquid_glass/glass_testing.dart';
import 'package:adaptive_liquid_glass_example/quick_start.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'the quick start builds, switches tabs and opens a sheet',
    (t) async {
      final ios = defaultTargetPlatform == TargetPlatform.iOS;
      // iOS 26 takes the glass path; Android takes Material 3.
      GlassTesting.setUp(iosMajorVersion: ios ? 26 : null);
      addTearDown(GlassTesting.reset);
      await t.pumpWidget(const QuickStartApp());
      await t.pump(const Duration(seconds: 1));
      expect(
        find.text(ios ? 'Hello, glass' : 'Hello, Material'),
        findsOneWidget,
      );

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

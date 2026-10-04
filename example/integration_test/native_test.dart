import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass_example/native_demo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // The pixel check is done on the host: `binding.takeScreenshot` is
  // unreliable on the iOS simulator and only captures Flutter content, and
  // the native glass is a UIKit view. Run `lib/native_demo.dart` and take
  // `xcrun simctl io <udid> screenshot` instead (see the task 13 report).
  testWidgets('native glass hosts a UiKitView on iOS 26', (tester) async {
    await tester.pumpWidget(const NativeDemo());
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(UiKitView), findsOneWidget);
    expect(find.byType(LiquidGlass), findsOneWidget);
  });
}

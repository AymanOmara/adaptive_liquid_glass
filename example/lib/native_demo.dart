import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/widgets.dart';

/// `flutter run -t lib/native_demo.dart`: native glass (the iOS 26+
/// default) over black and white stripes, for host screenshots.
void main() => runApp(const NativeDemo());

/// A 200 x 60 native glass capsule at (100, 300) over 30 vertical stripes.
class NativeDemo extends StatelessWidget {
  /// Creates the demo.
  const NativeDemo({super.key});

  @override
  Widget build(BuildContext context) {
    // Physical stripes and position: the scene is a fixed pixel fixture.
    return MediaQuery.fromView(
      view: View.of(context),
      child: Directionality(
        textDirection: TextDirection.ltr,
        // No theme or flag: iOS 26+ draws SwiftUI's own glass by default.
        child: Stack(
          children: [
            Positioned.fill(
              // Stretch: a childless ColoredBox takes the smallest
              // height the Row allows, which is zero.
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < 30; i++)
                    Expanded(
                      child: ColoredBox(
                        color: i.isEven
                            ? const Color(0xFF000000)
                            : const Color(0xFFFFFFFF),
                      ),
                    ),
                ],
              ),
            ),
            const Positioned(
              left: 100,
              top: 300,
              width: 200,
              height: 60,
              child: LiquidGlass(child: SizedBox.expand()),
            ),
          ],
        ),
      ),
    );
  }
}

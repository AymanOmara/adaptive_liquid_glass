import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts shown unless created dismissed', () {
    expect(GlassTipController().isDismissed, isFalse);
    expect(GlassTipController(dismissed: true).isDismissed, isTrue);
  });

  test('dismiss reports the reason once and notifies', () {
    final reasons = <GlassTipDismissReason>[];
    var notified = 0;
    final c = GlassTipController(onDismissed: reasons.add)
      ..addListener(() => notified++);
    c.dismiss();
    c.dismiss(GlassTipDismissReason.actionPerformed);
    expect(c.isDismissed, isTrue);
    expect(reasons, [GlassTipDismissReason.closed]);
    expect(notified, 1);
  });

  test('reset shows the tip again', () {
    final c = GlassTipController(dismissed: true);
    var notified = 0;
    c.addListener(() => notified++);
    c.reset();
    expect(c.isDismissed, isFalse);
    expect(notified, 1);
  });
}

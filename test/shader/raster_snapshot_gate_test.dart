import 'package:adaptive_liquid_glass/src/shader/raster_snapshot_gate.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// Snapshots without an onscreen surface crash Impeller's Android GLES
// backend (Flutter 3.47): the gate stays shut until a frame is rasterised
// and while the app is in the background.
void main() {
  setUp(() => RasterSnapshotGate.debugOverride = null);
  tearDown(() => RasterSnapshotGate.debugOverride = true);

  testWidgets('shut until the first frame is rasterised', (t) async {
    await t.pumpWidget(const SizedBox());
    // Widget tests never rasterise a frame.
    expect(WidgetsBinding.instance.firstFrameRasterized, isFalse);
    expect(RasterSnapshotGate.instance.isOpen, isFalse);
  });

  testWidgets('notifies on lifecycle changes', (t) async {
    var calls = 0;
    void listener() => calls++;
    RasterSnapshotGate.instance.addListener(listener);
    addTearDown(() => RasterSnapshotGate.instance.removeListener(listener));
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(calls, 2);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  test('the override wins', () {
    RasterSnapshotGate.debugOverride = true;
    expect(RasterSnapshotGate.instance.isOpen, isTrue);
    RasterSnapshotGate.debugOverride = false;
    expect(RasterSnapshotGate.instance.isOpen, isFalse);
  });
}

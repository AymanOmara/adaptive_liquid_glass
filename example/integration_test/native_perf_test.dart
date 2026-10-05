import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass_example/gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Rough frame-time indicator, native vs shader, scrolling the Gallery.
///
/// Run `flutter test integration_test/native_perf_test.dart` on a device
/// with `--dart-define=GLASS_MODE=shader` (default `auto`, native on iOS
/// 26+). FrameTiming covers Flutter's build and raster threads only, not
/// the Core Animation work of the platform view.
/// Profile mode is not available on the iOS simulator, so this runs in
/// debug: compare the two modes against each other, not against budgets.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  const modeName = String.fromEnvironment('GLASS_MODE', defaultValue: 'auto');
  final mode = GlassRenderMode.values.byName(modeName);

  testWidgets('gallery scroll frame times ($modeName)', (tester) async {
    await tester.pumpWidget(
      LiquidGlassTheme(
        data: LiquidGlassThemeData(defaultMode: mode),
        child: const MaterialApp(home: Gallery()),
      ),
    );
    await tester.pumpAndSettle();
    final timings = <FrameTiming>[];
    void collect(List<FrameTiming> t) => timings.addAll(t);
    SchedulerBinding.instance.addTimingsCallback(collect);
    for (var i = 0; i < 6; i++) {
      await tester.fling(
        find.byType(ListView),
        Offset(0, i.isEven ? -300 : 300),
        1500,
      );
      await tester.pumpAndSettle();
    }
    // Timings are reported in batches; give the last batch time to arrive.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    SchedulerBinding.instance.removeTimingsCallback(collect);

    double ms(Duration d) => d.inMicroseconds / 1000;
    List<double> sorted(Iterable<double> v) => v.toList()..sort();
    double pct(List<double> v, double p) => v[((v.length - 1) * p).round()];
    final build = sorted(timings.map((t) => ms(t.buildDuration)));
    final raster = sorted(timings.map((t) => ms(t.rasterDuration)));
    final total = sorted(timings.map((t) => ms(t.totalSpan)));
    // ignore: avoid_print
    print(
      'PERF $modeName frames=${timings.length} '
      'build p50=${pct(build, .5).toStringAsFixed(2)} '
      'p90=${pct(build, .9).toStringAsFixed(2)} '
      'raster p50=${pct(raster, .5).toStringAsFixed(2)} '
      'p90=${pct(raster, .9).toStringAsFixed(2)} '
      'total p50=${pct(total, .5).toStringAsFixed(2)} '
      'p90=${pct(total, .9).toStringAsFixed(2)} ms',
    );
    expect(timings, isNotEmpty);
  });
}

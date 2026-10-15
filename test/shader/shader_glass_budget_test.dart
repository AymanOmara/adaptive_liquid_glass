import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/degraded/degraded_glass.dart';
import 'package:adaptive_liquid_glass/src/layer/glass_layer.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_backdrop.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/shader/shader_glass_budget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final android = TargetPlatformVariant.only(TargetPlatform.android);
final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

void env() {
  GlassPlatform.instance.debugEnvironment = GlassEnvironment(
    platform: defaultTargetPlatform,
    iosMajorVersion: defaultTargetPlatform == TargetPlatform.iOS ? 18 : null,
    reduceTransparency: false,
    shaderSupported: true,
  );
}

const _unset = Object();

/// [n] standalone shader glasses keyed 0..n-1 (each its own group).
Widget glasses(
  Iterable<int> keys, {
  Object? budget = 4,
  Widget Function(int i, Widget glass)? wrap,
}) {
  env(); // after the variant set the platform
  const base = LiquidGlassThemeData(defaultMode: GlassRenderMode.shader);
  return MediaQuery(
    data: MediaQueryData.fromView(
      WidgetsBinding.instance.platformDispatcher.implicitView!,
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: LiquidGlassTheme(
        data: identical(budget, _unset)
            ? base
            : base.copyWith(androidShaderBudget: budget as int?),
        child: Wrap(
          children: [
            for (final i in keys)
              (wrap ?? (_, g) => g)(
                i,
                LiquidGlass(
                  key: ValueKey(i),
                  child: const SizedBox(width: 20, height: 20),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

bool shaderOf(int i) => find
    .descendant(
      of: find.byKey(ValueKey(i)),
      matching: find.byType(GlassBackdrop),
    )
    .evaluate()
    .isNotEmpty;

bool frostedOf(int i) => find
    .descendant(
      of: find.byKey(ValueKey(i)),
      matching: find.byType(DegradedGlass),
    )
    .evaluate()
    .isNotEmpty;

/// What [body] prints with `debugPrint` (restored before the test ends:
/// the binding checks it).
Future<List<String>> printsDuring(Future<void> Function() body) async {
  final printed = <String>[];
  final saved = debugPrint;
  debugPrint = (m, {wrapWidth}) => printed.add(m ?? '');
  try {
    await body();
  } finally {
    debugPrint = saved;
  }
  return printed;
}

void main() {
  setUp(() {
    GlassProgram.instance.debugReset(skipLoad: true);
    ShaderGlassBudget.debugWarned = false;
    // The budget counts glass outside the shared layer.
    GlassSharedLayer.debugEnabled = false;
  });

  tearDown(() {
    GlassSharedLayer.debugEnabled = null;
    GlassPlatform.instance.debugReset();
    GlassProgram.instance.debugReset();
  });

  testWidgets('no cap by default', (t) async {
    await t.pumpWidget(glasses(List.generate(6, (i) => i), budget: _unset));
    expect(find.byType(GlassBackdrop), findsNWidgets(6));
  }, variant: android);

  testWidgets('budget 4: the first 4 groups keep the shader', (t) async {
    await t.pumpWidget(glasses(List.generate(6, (i) => i)));
    expect(find.byType(GlassBackdrop), findsNWidgets(4));
    for (var i = 0; i < 4; i++) {
      expect(shaderOf(i), isTrue, reason: '$i');
    }
    expect(frostedOf(4), isTrue);
    expect(frostedOf(5), isTrue);
  }, variant: android);

  testWidgets('a GlassGroup counts once, whatever its members', (t) async {
    await t.pumpWidget(
      glasses(
        List.generate(4, (i) => i),
        wrap: (i, g) => GlassGroup(
          key: ValueKey('g$i'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              g,
              const LiquidGlass(child: SizedBox(width: 8)),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(GlassBackdrop), findsNWidgets(4));
    expect(find.byType(DegradedGlass), findsNothing);
  }, variant: android);

  testWidgets('a waiting group is promoted on the next frame', (t) async {
    await t.pumpWidget(glasses([0, 1, 2, 3, 4, 5]));
    expect(frostedOf(4), isTrue);
    await t.pumpWidget(glasses([1, 2, 3, 4, 5]));
    // Not in the frame that unmounted 0: no swap mid-frame.
    expect(frostedOf(4), isTrue);
    await t.pump();
    expect(shaderOf(4), isTrue);
    expect(frostedOf(5), isTrue);
    expect(find.byType(GlassBackdrop), findsNWidgets(4));
  }, variant: android);

  testWidgets('the theme sets the budget; null is unlimited', (t) async {
    final printed = await printsDuring(() async {
      await t.pumpWidget(glasses(List.generate(6, (i) => i), budget: 2));
      expect(find.byType(GlassBackdrop), findsNWidgets(2));
      expect(shaderOf(1), isTrue);
      expect(frostedOf(2), isTrue);

      await t.pumpWidget(glasses(List.generate(6, (i) => i), budget: null));
      await t.pump();
      expect(find.byType(GlassBackdrop), findsNWidgets(6));
    });
    expect(
      printed.where((m) => m.contains('androidShaderBudget')),
      hasLength(1),
    );
  }, variant: android);

  testWidgets('over budget warns once in debug', (t) async {
    final printed = await printsDuring(() async {
      await t.pumpWidget(glasses(List.generate(4, (i) => i)));
      expect(ShaderGlassBudget.debugWarned, isFalse);
      await t.pumpWidget(glasses(List.generate(8, (i) => i)));
    });
    final warnings = printed.where((m) => m.contains('GlassGroup')).toList();
    expect(warnings, hasLength(1));
    expect(warnings.single, contains('MB'));
  }, variant: android);

  testWidgets('priority glass (the tab bar) goes first', (t) async {
    await t.pumpWidget(
      glasses(
        List.generate(5, (i) => i),
        wrap: (i, g) => i == 4 ? ShaderBudgetPriority(child: g) : g,
      ),
    );
    expect(shaderOf(4), isTrue);
    // The newcomer displaces the last one, after the frame.
    await t.pump();
    expect(frostedOf(3), isTrue);
    expect(find.byType(GlassBackdrop), findsNWidgets(4));
  }, variant: android);

  testWidgets('glass hidden under an opaque route does not count', (t) async {
    await t.pumpWidget(
      glasses(
        List.generate(8, (i) => i),
        wrap: (i, g) => TickerMode(enabled: i >= 4, child: g),
      ),
    );
    for (var i = 4; i < 8; i++) {
      expect(shaderOf(i), isTrue, reason: '$i');
    }
  }, variant: android);

  testWidgets('iOS is unaffected', (t) async {
    final printed = await printsDuring(() async {
      await t.pumpWidget(glasses(List.generate(8, (i) => i)));
    });
    expect(find.byType(GlassBackdrop), findsNWidgets(8));
    expect(printed, isEmpty);
  }, variant: ios);

  testWidgets('released tickets leave the budget', (t) async {
    await t.pumpWidget(glasses(List.generate(6, (i) => i)));
    final element = t.element(find.byKey(const ValueKey(0)));
    final budget = ShaderGlassBudget.of(element);
    expect(budget.debugTicketCount, 6);
    await t.pumpWidget(glasses(const []));
    expect(budget.debugTicketCount, 0);
  }, variant: android);
}

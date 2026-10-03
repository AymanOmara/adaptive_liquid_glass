import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/material/material_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: b),
  ),
  home: Scaffold(body: Center(child: child)),
);

Material materialOf(WidgetTester t) => t.widget<Material>(
  find
      .descendant(
        of: find.byType(MaterialGlass),
        matching: find.byType(Material),
      )
      .first,
);

void main() {
  testWidgets('regular → surfaceContainerHigh, elevation 1, stadium', (
    t,
  ) async {
    await t.pumpWidget(
      host(
        const MaterialGlass(
          glass: Glass.regular,
          shape: GlassShape.capsule(),
          child: Text('hi'),
        ),
      ),
    );
    final m = materialOf(t);
    final scheme = Theme.of(t.element(find.text('hi'))).colorScheme;
    expect(m.color, scheme.surfaceContainerHigh);
    expect(m.elevation, 1);
    expect(m.shape, isA<StadiumBorder>());
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('clear → translucent surfaceContainerLow, no elevation', (
    t,
  ) async {
    await t.pumpWidget(
      host(
        const MaterialGlass(
          glass: Glass.clear,
          shape: GlassShape.rect(12),
          child: Text('hi'),
        ),
      ),
    );
    final m = materialOf(t);
    final scheme = Theme.of(t.element(find.text('hi'))).colorScheme;
    expect(m.color, scheme.surfaceContainerLow.withValues(alpha: 0.85));
    expect(m.elevation, 0);
    expect(m.shape, isA<RoundedSuperellipseBorder>());
  });

  testWidgets('tint → primaryContainer of a seeded scheme', (t) async {
    await t.pumpWidget(
      host(
        MaterialGlass(
          glass: Glass.regular.tint(Colors.orange),
          shape: const GlassShape.circle(),
          child: const Text('hi'),
        ),
      ),
    );
    expect(
      materialOf(t).color,
      ColorScheme.fromSeed(seedColor: Colors.orange).primaryContainer,
    );
  });

  testWidgets('interactive adds a ripple without stealing child taps', (
    t,
  ) async {
    var taps = 0;
    await t.pumpWidget(
      host(
        MaterialGlass(
          glass: Glass.regular.interactive(),
          shape: const GlassShape.capsule(),
          child: TextButton(onPressed: () => taps++, child: const Text('go')),
        ),
      ),
    );
    expect(find.byType(InkWell), findsWidgets);
    await t.tap(find.text('go'));
    expect(taps, 1);
  });

  testWidgets('identity renders only the child', (t) async {
    await t.pumpWidget(
      host(
        const MaterialGlass(
          glass: Glass.identity,
          shape: GlassShape.capsule(),
          child: Text('hi'),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(MaterialGlass),
        matching: find.byType(Material),
      ),
      findsNothing,
    );
  });

  testWidgets('fadeIn animates opacity from 0 to 1', (t) async {
    await t.pumpWidget(
      host(
        const MaterialGlass(
          glass: Glass.regular,
          shape: GlassShape.capsule(),
          fadeIn: true,
          child: Text('hi'),
        ),
      ),
    );
    expect(t.widget<Opacity>(find.byType(Opacity)).opacity, 0);
    await t.pumpAndSettle();
    expect(t.widget<Opacity>(find.byType(Opacity)).opacity, 1);
  });
}

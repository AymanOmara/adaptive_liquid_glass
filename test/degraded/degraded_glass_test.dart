import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/degraded/degraded_glass.dart';
import 'package:adaptive_liquid_glass/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget c) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(),
    child: Center(child: c),
  ),
);

void main() {
  testWidgets('blur + clip when not opaque', (t) async {
    await t.pumpWidget(
      host(
        const DegradedGlass(
          glass: Glass.regular,
          shape: GlassShape.capsule(),
          constants: GlassConstants.standard,
          child: Text('hi'),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(ClipPath), findsOneWidget);
  });

  testWidgets('untinted fill is fillColor at fillOpacity', (t) async {
    await t.pumpWidget(
      host(
        const DegradedGlass(
          glass: Glass.regular,
          shape: GlassShape.capsule(),
          constants: GlassConstants.standard,
          child: Text('hi'),
        ),
      ),
    );
    final box = t.widget<DecoratedBox>(find.byType(DecoratedBox));
    final r = GlassConstants.standard.regular;
    expect(
      (box.decoration as ShapeDecoration).color,
      r.fillColor.withValues(alpha: r.fillOpacity),
    );
  });

  testWidgets('opaque draws a solid shape and no backdrop', (t) async {
    await t.pumpWidget(
      host(
        const DegradedGlass(
          glass: Glass.regular,
          shape: GlassShape.capsule(),
          constants: GlassConstants.standard,
          opaqueColor: Color(0xFFF2F2F7),
          child: Text('hi'),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    final box = t.widget<DecoratedBox>(find.byType(DecoratedBox));
    expect((box.decoration as ShapeDecoration).color, const Color(0xFFF2F2F7));
  });
}

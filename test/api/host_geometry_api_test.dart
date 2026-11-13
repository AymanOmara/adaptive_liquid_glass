import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/material/material_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hosts.dart';

/// Host-app geometry, direction and surface APIs (CashRoot W36–W41).
void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  Widget app(Widget child, {TextDirection dir = TextDirection.ltr}) =>
      MaterialApp(
        home: Directionality(
          textDirection: dir,
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(width: 340, child: child),
            ),
          ),
        ),
      );

  group('W41 GlassTextField geometry', () {
    testWidgets('Hakim composer: minHeight 52, padding 4, 44 pt button', (
      t,
    ) async {
      shaderEnv();
      await t.pumpWidget(
        app(
          GlassTextField(
            minHeight: 52,
            contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 4, 4, 4),
            suffix: const SizedBox.square(dimension: 44),
          ),
        ),
      );
      expect(t.getSize(find.byType(LiquidGlass)).height, 52);
      final glass = t.getRect(find.byType(LiquidGlass));
      final button = t.getRect(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 44 && w.height == 44,
        ),
      );
      expect(glass.right - button.right, 4);
      expect(button.top - glass.top, 4);
    }, variant: ios);

    testWidgets('a 38 pt form row is reachable', (t) async {
      shaderEnv();
      await t.pumpWidget(
        app(
          const GlassTextField(
            minHeight: 38,
            contentPadding: EdgeInsetsDirectional.symmetric(horizontal: 12),
          ),
        ),
      );
      expect(t.getSize(find.byType(LiquidGlass)).height, 38);
    }, variant: ios);

    testWidgets('multi-line honours minHeight and contentPadding', (t) async {
      shaderEnv();
      await t.pumpWidget(
        app(
          const GlassTextField(
            maxLines: 4,
            minLines: 1,
            minHeight: 60,
            contentPadding: EdgeInsetsDirectional.all(4),
          ),
        ),
      );
      expect(t.getSize(find.byType(LiquidGlass)).height, 60);
    }, variant: ios);

    test('TextFieldMetrics is exported', () {
      expect(TextFieldMetrics.height, 48);
    });
  });

  group('W40 GlassTextField direction and style', () {
    testWidgets('forwards textDirection, textAlign and style', (t) async {
      shaderEnv();
      await t.pumpWidget(
        app(
          const GlassTextField(
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.end,
            style: TextStyle(color: Color(0xFF00FF00)),
          ),
          dir: TextDirection.rtl,
        ),
      );
      final field = t.widget<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      expect(field.textDirection, TextDirection.ltr);
      expect(field.textAlign, TextAlign.end);
      expect(field.style!.color, const Color(0xFF00FF00));
      // The capsule still follows the app's direction.
      expect(
        Directionality.of(t.element(find.byType(LiquidGlass))),
        TextDirection.rtl,
      );
    }, variant: ios);

    testWidgets('Material: forwards them to the TextField', (t) async {
      shaderEnv();
      await t.pumpWidget(
        app(
          const GlassTextField(
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF00FF00)),
          ),
        ),
      );
      final field = t.widget<TextField>(find.byType(TextField));
      expect(field.textDirection, TextDirection.rtl);
      expect(field.textAlign, TextAlign.center);
      expect(field.style!.color, const Color(0xFF00FF00));
    }, variant: android);
  });

  group('W39 materialBuilder', () {
    testWidgets('GlassTextField wraps its Material TextField', (t) async {
      shaderEnv();
      TextField? seen;
      await t.pumpWidget(
        app(
          GlassTextField(
            materialBuilder: (context, field) {
              seen = field;
              return KeyedSubtree(key: const Key('wrapped'), child: field);
            },
          ),
        ),
      );
      expect(seen, isNotNull);
      expect(find.byKey(const Key('wrapped')), findsOneWidget);
    }, variant: android);

    testWidgets('GlassSearchField wraps its Material SearchBar', (t) async {
      shaderEnv();
      await t.pumpWidget(
        app(
          GlassSearchField(
            materialBuilder: (context, bar) =>
                KeyedSubtree(key: const Key('wrapped'), child: bar),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('wrapped')),
          matching: find.byType(SearchBar),
        ),
        findsOneWidget,
      );
    }, variant: android);
  });

  group('W36 GlassMenuButton materialStyle', () {
    testWidgets('compactMaterialStyle fits a 32 pt host', (t) async {
      shaderEnv();
      await t.pumpWidget(
        app(
          Center(
            child: GlassMenuButton(
              materialStyle: GlassMenuButton.compactMaterialStyle,
              items: [GlassMenuItem(label: 'Copy', onSelected: () {})],
            ),
          ),
        ),
      );
      expect(t.getSize(find.byType(IconButton)), const Size(32, 32));
    }, variant: android);
  });

  group('W37 GlassSheet contentSurface', () {
    testWidgets('paints the sheet opaque in that colour', (t) async {
      shaderEnv();
      const surface = Color(0xFF123456);
      await t.pumpWidget(
        app(
          const SizedBox(
            height: 300,
            child: GlassSheet(contentSurface: surface, child: Text('x')),
          ),
        ),
      );
      final boxes = t.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(GlassSheet),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        boxes.any(
          (b) =>
              b.decoration is ShapeDecoration &&
              (b.decoration as ShapeDecoration).color == surface,
        ),
        isTrue,
      );
      final opacity = t.widget<Opacity>(
        find
            .ancestor(
              of: find.byWidgetPredicate(
                (w) =>
                    w is DecoratedBox &&
                    w.decoration is ShapeDecoration &&
                    (w.decoration as ShapeDecoration).color == surface,
              ),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 1);
    }, variant: ios);

    testWidgets('Material: it is the bottom sheet background', (t) async {
      shaderEnv();
      const surface = Color(0xFF123456);
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showGlassSheet<void>(
                context: context,
                contentSurface: surface,
                builder: (_) => const Text('Sheet'),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      expect(
        t.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor,
        surface,
      );
    }, variant: android);
  });

  group('W38 GlassScrollEdge', () {
    Iterable<LinearGradient> gradients(WidgetTester t) => t
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(GlassScrollEdge),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((b) => (b.decoration as BoxDecoration).gradient)
        .whereType<LinearGradient>();

    testWidgets('a bottom edge fades upward in the given colour', (t) async {
      const color = Color(0xFF336699);
      await t.pumpWidget(
        app(
          const GlassScrollEdge(
            visible: true,
            height: 40,
            edge: GlassScrollEdgePosition.bottom,
            color: color,
          ),
        ),
      );
      final g = gradients(t).single;
      expect(g.begin, Alignment.bottomCenter);
      expect(g.end, Alignment.topCenter);
      expect(g.colors.first, color);
    });

    testWidgets('the default is a top edge', (t) async {
      await t.pumpWidget(app(const GlassScrollEdge(visible: true, height: 40)));
      expect(gradients(t).single.begin, Alignment.topCenter);
    });
  });

  group('W38 surfaces', () {
    test('materialSurface is kept by the other modifiers and in ==', () {
      const c = Color(0xFF00AA00);
      final g = Glass.regular.materialSurface(c);
      expect(g.materialSurfaceColor, c);
      expect(g.tint(Colors.red).materialSurfaceColor, c);
      expect(g.interactive().materialSurfaceColor, c);
      expect(g, Glass.regular.materialSurface(c));
      expect(g, isNot(Glass.regular));
      expect(g.hashCode, Glass.regular.materialSurface(c).hashCode);
      expect(g.materialSurface(null), Glass.regular);
    });

    testWidgets('Material: materialSurface colours the surface', (t) async {
      shaderEnv();
      const c = Color(0xFF00AA00);
      await t.pumpWidget(
        app(
          LiquidGlass(
            glass: Glass.regular.materialSurface(c),
            child: const SizedBox(width: 80, height: 40),
          ),
        ),
      );
      final material = t.widget<Material>(
        find
            .descendant(
              of: find.byType(MaterialGlass),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, c);
    }, variant: android);

    testWidgets('Material: colorOf is the painted surface', (t) async {
      shaderEnv();
      late BuildContext ctx;
      await t.pumpWidget(
        app(Builder(builder: (c) => SizedBox(key: Key('${ctx = c}')))),
      );
      const c = Color(0xFF00AA00);
      expect(
        GlassSurface.colorOf(ctx, glass: Glass.regular.materialSurface(c)),
        c,
      );
    }, variant: android);

    testWidgets('glass: colorOf is opaque and follows the backdrop', (t) async {
      shaderEnv();
      late BuildContext ctx;
      await t.pumpWidget(
        app(Builder(builder: (c) => SizedBox(key: Key('${ctx = c}')))),
      );
      final onWhite = GlassSurface.colorOf(
        ctx,
        backdrop: const Color(0xFFFFFFFF),
      );
      final onBlack = GlassSurface.colorOf(
        ctx,
        backdrop: const Color(0xFF000000),
      );
      expect(onWhite.a, 1);
      expect(onBlack.a, 1);
      expect(onWhite, isNot(onBlack));
      final tinted = GlassSurface.colorOf(
        ctx,
        glass: Glass.regular.tint(const Color(0xFFFF0000)),
        backdrop: const Color(0xFFFFFFFF),
      );
      expect(tinted.r, greaterThan(tinted.b));
    }, variant: ios);
  });
}

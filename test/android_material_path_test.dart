import 'dart:ui' as ui;

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/degraded/degraded_glass.dart';
import 'package:adaptive_liquid_glass/src/liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/material/material_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/shader/render_glass_backdrop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Material-path audit of the package on Android (spec §1 criterion 4:
/// every widget renders a Material 3 equivalent with no glass code path).
///
/// Every test runs with `debugDefaultTargetPlatformOverride` set to
/// [TargetPlatform.android] via [TargetPlatformVariant] (which resets it in
/// its teardown before the binding verifies foundation debug variables);
/// the file-level `tearDown` resets it again for good measure.
final android = TargetPlatformVariant.only(TargetPlatform.android);

void main() {
  setUp(() {
    GlassProgram.instance.debugReset(skipLoad: true);
    GlassPlatform.instance.debugEnvironment = GlassEnvironment(
      platform: TargetPlatform.android,
      iosMajorVersion: null,
      reduceTransparency: false,
      shaderSupported: ui.ImageFilter.isShaderFilterSupported,
    );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    GlassPlatform.instance.debugReset();
    GlassProgram.instance.debugReset();
  });

  Widget host(
    Widget child, {
    Brightness brightness = Brightness.light,
    Color seed = Colors.teal,
  }) => MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      ),
    ),
    home: Scaffold(body: Center(child: child)),
  );

  /// The Material surface a LiquidGlass renders, if any.
  Material materialOf(WidgetTester t) => t.widget<Material>(
    find
        .descendant(
          of: find.byType(MaterialGlass),
          matching: find.byType(Material),
        )
        .first,
  );

  /// Every layer below the root, depth-first.
  List<Layer> allLayers() {
    final layers = <Layer>[];
    void walk(Layer layer) {
      layers.add(layer);
      Layer? child = layer is ContainerLayer ? layer.firstChild : null;
      while (child != null) {
        walk(child);
        child = child.nextSibling;
      }
    }

    final root = WidgetsBinding.instance.renderViews.first.debugLayer;
    if (root != null) walk(root);
    return layers;
  }

  /// No glass or shader path may run on Android: no shader backdrop
  /// (widget, render object or layer), no degraded blur, no member boxes.
  void expectNoGlassPath(WidgetTester t) {
    expect(find.byType(GlassBackdrop), findsNothing);
    expect(find.byType(DegradedGlass), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(GlassMemberBox), findsNothing);
    expect(
      t.allRenderObjects.where(
        (r) => r is RenderGlassBackdrop || r is RenderGlassMember,
      ),
      isEmpty,
    );
    expect(allLayers().whereType<BackdropFilterLayer>(), isEmpty);
  }

  testWidgets('LiquidGlass renders a Material surface, not glass', (t) async {
    await t.pumpWidget(
      host(const LiquidGlass(child: SizedBox(width: 80, height: 40))),
    );
    expectNoGlassPath(t);
    final m = materialOf(t);
    expect(m.elevation, 1);
    expect(m.clipBehavior, Clip.antiAlias);
    expect(find.byType(InkWell), findsNothing); // not interactive
  }, variant: android);

  testWidgets('a group of three members is three Materials, no backdrop', (
    t,
  ) async {
    await t.pumpWidget(
      host(
        const GlassGroup(
          spacing: 20,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LiquidGlass(child: SizedBox(width: 72, height: 52)),
              SizedBox(width: 12),
              LiquidGlass(child: SizedBox(width: 72, height: 52)),
              SizedBox(width: 12),
              LiquidGlass(child: SizedBox(width: 72, height: 52)),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(MaterialGlass), findsNWidgets(3));
    expectNoGlassPath(t);
    final scheme = Theme.of(
      t.element(find.byType(MaterialGlass).first),
    ).colorScheme;
    for (final m in t.widgetList<Material>(
      find.descendant(
        of: find.byType(MaterialGlass),
        matching: find.byType(Material),
      ),
    )) {
      expect(m.color, scheme.surfaceContainerHigh);
    }
  }, variant: android);

  testWidgets('capsule maps to StadiumBorder', (t) async {
    await t.pumpWidget(
      host(const LiquidGlass(child: SizedBox(width: 80, height: 40))),
    );
    expect(materialOf(t).shape, isA<StadiumBorder>());
  }, variant: android);

  testWidgets('circle maps to CircleBorder', (t) async {
    await t.pumpWidget(
      host(
        const LiquidGlass(
          shape: GlassShape.circle(),
          child: SizedBox(width: 60, height: 60),
        ),
      ),
    );
    expect(materialOf(t).shape, isA<CircleBorder>());
  }, variant: android);

  testWidgets('rect(16) maps to RoundedSuperellipseBorder(16)', (t) async {
    await t.pumpWidget(
      host(
        const LiquidGlass(
          shape: GlassShape.rect(16),
          child: SizedBox(width: 80, height: 40),
        ),
      ),
    );
    final border = materialOf(t).shape;
    expect(border, isA<RoundedSuperellipseBorder>());
    expect(
      (border as RoundedSuperellipseBorder).borderRadius,
      BorderRadius.circular(16),
    );
  }, variant: android);

  testWidgets('concentric maps to StadiumBorder outside a container', (
    t,
  ) async {
    await t.pumpWidget(
      host(
        const LiquidGlass(
          shape: GlassShape.concentric(),
          child: SizedBox(width: 80, height: 40),
        ),
      ),
    );
    // Concentric inherits the capsule default when no glass encloses it.
    expect(materialOf(t).shape, isA<StadiumBorder>());
  }, variant: android);

  testWidgets('Glass.clear is translucent surfaceContainerLow at elevation 0', (
    t,
  ) async {
    await t.pumpWidget(
      host(
        const LiquidGlass(
          glass: Glass.clear,
          child: SizedBox(width: 80, height: 40),
        ),
      ),
    );
    expectNoGlassPath(t);
    final m = materialOf(t);
    final scheme = Theme.of(t.element(find.byType(MaterialGlass))).colorScheme;
    expect(m.color, scheme.surfaceContainerLow.withValues(alpha: 0.85));
    expect(m.elevation, 0);
  }, variant: android);

  testWidgets('Glass.regular.tint uses the seed of the tint colour', (t) async {
    await t.pumpWidget(
      host(
        LiquidGlass(
          glass: Glass.regular.tint(Colors.orange),
          shape: const GlassShape.circle(),
          child: const SizedBox(width: 60, height: 60),
        ),
      ),
    );
    expectNoGlassPath(t);
    final scheme = Theme.of(t.element(find.byType(MaterialGlass))).colorScheme;
    expect(
      materialOf(t).color,
      ColorScheme.fromSeed(
        seedColor: Colors.orange,
        brightness: scheme.brightness,
      ).primaryContainer,
    );
  }, variant: android);

  testWidgets('Glass.identity shows the child with no surface', (t) async {
    await t.pumpWidget(
      host(const LiquidGlass(glass: Glass.identity, child: Text('plain'))),
    );
    expect(find.text('plain'), findsOneWidget);
    expect(find.byType(MaterialGlass), findsNothing);
    expectNoGlassPath(t);
  }, variant: android);

  testWidgets('interactive glass gets an ink ripple clipped to the shape', (
    t,
  ) async {
    await t.pumpWidget(
      host(
        LiquidGlass(
          glass: Glass.regular.interactive(),
          child: const SizedBox(width: 80, height: 40),
        ),
      ),
    );
    expectNoGlassPath(t);
    final ink = t.widget<InkWell>(find.byType(InkWell));
    expect(ink.excludeFromSemantics, isTrue); // semantics come from the child
    expect(materialOf(t).clipBehavior, Clip.antiAlias);
  }, variant: android);

  testWidgets('the light theme drives the Material colour', (t) async {
    await t.pumpWidget(
      host(
        const LiquidGlass(child: SizedBox(width: 80, height: 40)),
        brightness: Brightness.light,
      ),
    );
    expectNoGlassPath(t);
    final scheme = Theme.of(t.element(find.byType(MaterialGlass))).colorScheme;
    expect(materialOf(t).color, scheme.surfaceContainerHigh);
    expect(scheme.brightness, Brightness.light);
  }, variant: android);

  testWidgets('the dark theme drives the Material colour', (t) async {
    await t.pumpWidget(
      host(
        const LiquidGlass(child: SizedBox(width: 80, height: 40)),
        brightness: Brightness.dark,
      ),
    );
    expectNoGlassPath(t);
    final scheme = Theme.of(t.element(find.byType(MaterialGlass))).colorScheme;
    expect(materialOf(t).color, scheme.surfaceContainerHigh);
    expect(scheme.brightness, Brightness.dark);
    // Not a constant: the dark surface tone differs from the light one.
    final light = ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.light,
    ).surfaceContainerHigh;
    expect(scheme.surfaceContainerHigh, isNot(light));
  }, variant: android);

  testWidgets('the colour follows the consumer scheme, not a constant', (
    t,
  ) async {
    await t.pumpWidget(
      host(
        const LiquidGlass(child: SizedBox(width: 80, height: 40)),
        seed: Colors.deepPurple,
      ),
    );
    final scheme = Theme.of(t.element(find.byType(MaterialGlass))).colorScheme;
    expect(materialOf(t).color, scheme.surfaceContainerHigh);
  }, variant: android);

  testWidgets(
    'explicit mode:shader on Android is honored (documented deviation)',
    (t) async {
      // Spec §5 step 1: an explicit mode other than auto wins, so shader
      // glass (or the blur-only degraded surface when the shader filter is
      // unsupported) really runs on Android. Spec §12: allowed but
      // unsupported/untested. This records what happens.
      final shaderSupported = ui.ImageFilter.isShaderFilterSupported;
      await t.pumpWidget(
        host(
          const LiquidGlass(
            mode: GlassRenderMode.shader,
            child: SizedBox(width: 80, height: 40),
          ),
        ),
      );
      expect(find.byType(MaterialGlass), findsNothing);
      if (shaderSupported) {
        expect(find.byType(GlassBackdrop), findsOneWidget);
        expect(
          t.renderObjectList<RenderGlassBackdrop>(find.byType(GlassBackdrop)),
          isNotEmpty,
        );
      } else {
        expect(find.byType(DegradedGlass), findsOneWidget);
        expect(find.byType(BackdropFilter), findsOneWidget);
        expect(find.byType(GlassBackdrop), findsNothing);
      }
      expect(t.takeException(), isNull);
    },
    variant: android,
  );
}

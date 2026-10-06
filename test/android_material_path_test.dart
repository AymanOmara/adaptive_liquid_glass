import 'dart:ui' as ui;

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/degraded/degraded_glass.dart';
import 'package:adaptive_liquid_glass/src/group/glass_member_box.dart';
import 'package:adaptive_liquid_glass/src/group/render_glass_member.dart';
import 'package:adaptive_liquid_glass/src/material/material_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_backdrop.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/shader/render_glass_backdrop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Material-path audit of the package on Android (spec §1 criterion 4:
/// every widget renders a Material 3 equivalent with no glass code path).
///
/// Updated for the U1 API (`glassEffect()`, `padding`, `onPressed`,
/// `adaptiveForeground`): the A1 findings 4.3 (shader load on Android) and
/// 4.6 (no-op `onTap`) are asserted as fixed here.
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
    // The ink-well structure is always built (so toggling onPressed keeps
    // the child mounted); with nothing to press it is inert, not a no-op
    // button: no tap handler, no focus, no semantics.
    final ink = t.widget<InkWell>(find.byType(InkWell));
    expect(ink.onTap, isNull);
    expect(ink.canRequestFocus, isFalse);
    expect(ink.excludeFromSemantics, isTrue);
  }, variant: android);

  testWidgets('the shader program is never loaded on the Material path', (
    t,
  ) async {
    // A1 finding 4.3, fixed: GlassProgram.load() ran for every group. Now
    // only the backdrop path loads it. Arm a real load (it fails and is
    // reported under `flutter test`), pump the Material path and assert
    // neither the load nor its failure ever happens.
    GlassProgram.instance.debugReset();
    await t.pumpWidget(
      host(const LiquidGlass(child: SizedBox(width: 80, height: 40))),
    );
    await t.pump();
    expect(t.takeException(), isNull); // no failed asset load was reported
    expect(GlassProgram.instance.program.value, isNull); // nothing loaded
    expectNoGlassPath(t);
  }, variant: android);

  testWidgets('onPressed fires on the Material path', (t) async {
    // A1 finding 4.6, fixed: the ink well's tap was a no-op. onPressed is
    // now a real button callback.
    var taps = 0;
    await t.pumpWidget(
      host(LiquidGlass(onPressed: () => taps++, child: const Text('Go'))),
    );
    expectNoGlassPath(t);
    await t.tap(find.text('Go'));
    await t.pumpAndSettle();
    expect(taps, 1);
    // The padding is part of the button (inside the capsule's end cap).
    await t.pumpWidget(
      host(
        LiquidGlass(
          onPressed: () => taps++,
          padding: const EdgeInsets.all(12),
          child: const Text('Go'),
        ),
      ),
    );
    await t.tapAt(
      t
          .getCenter(find.byType(LiquidGlass))
          .translate(-t.getSize(find.byType(LiquidGlass)).width / 2 + 8, 0),
    );
    await t.pumpAndSettle();
    expect(taps, 2);
  }, variant: android);

  testWidgets('button semantics follow onPressed', (t) async {
    final semantics = t.ensureSemantics();
    await t.pumpWidget(
      host(LiquidGlass(onPressed: () {}, child: const Text('Go'))),
    );
    expect(
      t.getSemantics(find.text('Go')),
      isSemantics(
        label: 'Go',
        isButton: true,
        hasTapAction: true,
        isFocusable: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );
    // Without onPressed the glass is not a button.
    await t.pumpWidget(host(const LiquidGlass(child: Text('Go'))));
    expect(t.getSemantics(find.text('Go')), isNot(isSemantics(isButton: true)));
    semantics.dispose();
  }, variant: android);

  testWidgets("Text('x').glassEffect() renders a Material capsule", (t) async {
    await t.pumpWidget(host(const Text('x').glassEffect()));
    expect(find.text('x'), findsOneWidget);
    expect(find.byType(MaterialGlass), findsOneWidget);
    expectNoGlassPath(t);
    final m = materialOf(t);
    expect(m.shape, isA<StadiumBorder>()); // the glassEffect capsule default
    final scheme = Theme.of(t.element(find.byType(MaterialGlass))).colorScheme;
    expect(m.color, scheme.surfaceContainerHigh); // regular default glass
  }, variant: android);

  testWidgets('padding insets the child inside the Material surface', (
    t,
  ) async {
    const key = Key('content');
    await t.pumpWidget(
      host(
        const LiquidGlass(
          padding: EdgeInsetsDirectional.only(
            start: 16,
            end: 4,
            top: 8,
            bottom: 2,
          ),
          child: SizedBox(key: key, width: 40, height: 20),
        ),
      ),
    );
    expectNoGlassPath(t);
    expect(t.getSize(find.byType(LiquidGlass)), const Size(60, 30));
    final glass = t.getTopLeft(find.byType(LiquidGlass));
    expect(t.getTopLeft(find.byKey(key)) - glass, const Offset(16, 8));
  }, variant: android);

  testWidgets('the adaptive foreground labels with onSurface', (t) async {
    late BuildContext probe;
    await t.pumpWidget(
      host(
        LiquidGlass(
          child: Builder(
            builder: (c) {
              probe = c;
              return const Text('label');
            },
          ),
        ),
      ),
    );
    expectNoGlassPath(t);
    final scheme = Theme.of(probe).colorScheme;
    expect(DefaultTextStyle.of(probe).style.color, scheme.onSurface);
    expect(IconTheme.of(probe).color, scheme.onSurface);
  }, variant: android);

  testWidgets('tinted glass labels with onPrimaryContainer', (t) async {
    late BuildContext probe;
    await t.pumpWidget(
      host(
        LiquidGlass(
          glass: Glass.regular.tint(Colors.orange),
          child: Builder(
            builder: (c) {
              probe = c;
              return const Text('label');
            },
          ),
        ),
      ),
    );
    expectNoGlassPath(t);
    final seeded = ColorScheme.fromSeed(
      seedColor: Colors.orange,
      brightness: Theme.of(probe).brightness,
    );
    expect(DefaultTextStyle.of(probe).style.color, seeded.onPrimaryContainer);
    expect(IconTheme.of(probe).color, seeded.onPrimaryContainer);
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
    expect(ink.onTap, isNotNull); // the empty callback enables the ripple
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

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/layer/glass_layer_plan.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_backdrop_config.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_backdrop_debug_frame.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_frame_uniforms.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_shape_uniform.dart';
import 'package:adaptive_liquid_glass/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _config = GlassBackdropConfig(
  spacing: 0,
  lightAngle: -2,
  devicePixelRatio: 2,
  constants: GlassConstants.standard,
  brightness: Brightness.light,
  highContrast: false,
);

LayerGroupInput g(
  String id,
  Rect bounds, {
  List<int>? order,
  double sigma = 3,
  double aspect = 1,
  int shapes = 1,
  Rect? clip,
  Path? clipPath,
  double opacity = 1,
  GlassBackdropConfig config = _config,
  double smoothing = 0,
  Offset? touch,
  double glow = 0,
}) => LayerGroupInput(
  id: id,
  order: order ?? [int.parse(id.substring(1))],
  frame: GlassBackdropDebugFrame(
    GlassFrameUniforms(
      shapes: [
        for (var i = 0; i < shapes; i++)
          GlassShapeUniform(
            rect: (bounds.deflate(4)).shift(Offset(i * 0.1, 0)),
            radius: 4,
            variant: GlassVariant.regular,
          ),
      ],
      devicePixelRatio: config.devicePixelRatio,
      lightAngle: config.lightAngle,
      smoothing: smoothing,
      constants: config.constants,
      brightness: config.brightness,
      touch: touch,
      glow: glow,
    ),
    bounds,
    bounds.topLeft,
    sigma,
    aspect,
  ),
  bounds: bounds,
  config: config,
  clip: clip,
  clipPath: clipPath,
  opacity: opacity,
);

void main() {
  test('separate groups share one stratum and one pass', () {
    final plan = planGlassLayer([
      g('g0', const Rect.fromLTWH(0, 0, 50, 50)),
      g('g1', const Rect.fromLTWH(100, 0, 50, 50)),
      g('g2', const Rect.fromLTWH(0, 100, 50, 50)),
    ]);
    expect(plan, hasLength(1));
    expect(plan.single.passes, hasLength(1));
    final pass = plan.single.passes.single;
    expect(pass.groups, ['g0', 'g1', 'g2']);
    expect(pass.uniforms.shapes.map((s) => s.group), [0, 1, 2]);
    expect(pass.bounds, const Rect.fromLTWH(0, 0, 150, 150));
  });

  test('a later overlapping group goes to the next stratum', () {
    final plan = planGlassLayer([
      // Listed out of order: paint order decides.
      g('g1', const Rect.fromLTWH(0, 80, 400, 60), order: [5]), // tab bar
      g('g0', const Rect.fromLTWH(10, 100, 50, 50), order: [2, 7]), // content
      g('g2', const Rect.fromLTWH(300, 0, 50, 50), order: [6]), // clear
    ]);
    expect(plan.map((s) => s.groups), [
      ['g0', 'g2'],
      ['g1'],
    ]);
  });

  test('strata chain: each overlap pushes one further', () {
    final plan = planGlassLayer([
      g('g0', const Rect.fromLTWH(0, 0, 100, 100)),
      g('g1', const Rect.fromLTWH(50, 50, 100, 100)),
      g('g2', const Rect.fromLTWH(120, 120, 100, 100)),
      g('g3', const Rect.fromLTWH(500, 0, 10, 10)),
    ]);
    expect(plan.map((s) => s.groups), [
      ['g0', 'g3'],
      ['g1'],
      ['g2'],
    ]);
  });

  test('the clip cuts the region used for overlap', () {
    final plan = planGlassLayer([
      g('g0', const Rect.fromLTWH(0, 0, 100, 100)),
      g(
        'g1',
        const Rect.fromLTWH(50, 50, 100, 100),
        clip: const Rect.fromLTWH(100, 0, 400, 400),
      ),
    ]);
    expect(plan, hasLength(1));
    final s1 = plan.single.passes.single.uniforms.shapes[1];
    expect(s1.clip, const Rect.fromLTWH(200, 0, 800, 800)); // x dpr 2
  });

  test('a rounded clip shapes its group in the pass only', () {
    final round = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 100, 40),
          const Radius.circular(20),
        ),
      );
    final plan = planGlassLayer([
      g('g0', const Rect.fromLTWH(0, 0, 100, 40), clipPath: round),
      g('g1', const Rect.fromLTWH(0, 100, 100, 40)),
    ]);
    final pass = plan.single.passes.single;
    final p = pass.clipPath!;
    expect(p.contains(const Offset(50, 20)), isTrue);
    expect(p.contains(const Offset(1, 1)), isFalse); // g0's corner
    expect(p.contains(const Offset(1, 101)), isTrue); // g1 stays square
    expect(p.contains(const Offset(50, 70)), isFalse); // between groups
  });

  test("a neighbour's margin does not undo a rounded clip", () {
    final round = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(100, 0, 100, 100),
          const Radius.circular(30),
        ),
      );
    const dpr1 = GlassBackdropConfig(
      spacing: 0,
      lightAngle: -2,
      devicePixelRatio: 1,
      constants: GlassConstants.standard,
      brightness: Brightness.light,
      highContrast: false,
    );
    final plan = planGlassLayer([
      // g0's bounds (shadow margin) reach over g1's left corners.
      g('g0', const Rect.fromLTWH(0, 0, 103, 100), config: dpr1),
      g(
        'g1',
        const Rect.fromLTWH(96, -4, 108, 108),
        clipPath: round,
        config: dpr1,
      ),
    ]);
    final p = plan.single.passes.single.clipPath!;
    expect(p.contains(const Offset(101, 1)), isFalse); // g1's corner
    expect(p.contains(const Offset(150, 50)), isTrue);
    expect(p.contains(const Offset(50, 50)), isTrue);
  });

  test('no shaped clip: the pass clips to its bounds', () {
    final plan = planGlassLayer([g('g0', const Rect.fromLTWH(0, 0, 50, 50))]);
    expect(plan.single.passes.single.clipPath, isNull);
  });

  test('invisible and fully clipped groups are dropped', () {
    final plan = planGlassLayer([
      g('g0', const Rect.fromLTWH(0, 0, 100, 100), opacity: 0),
      g(
        'g1',
        const Rect.fromLTWH(0, 0, 100, 100),
        clip: const Rect.fromLTWH(200, 0, 10, 10),
      ),
      g('g2', const Rect.fromLTWH(0, 0, 100, 100), opacity: 0.5),
    ]);
    expect(plan.single.groups, ['g2']);
    expect(plan.single.passes.single.uniforms.shapes.single.opacity, 0.5);
  });

  test('distinct blurs split passes, merged down to the cap', () {
    final plan = planGlassLayer([
      g('g0', const Rect.fromLTWH(0, 0, 10, 10), sigma: 1),
      g('g1', const Rect.fromLTWH(20, 0, 10, 10), sigma: 1.1),
      g('g2', const Rect.fromLTWH(40, 0, 10, 10), sigma: 4),
      g('g3', const Rect.fromLTWH(60, 0, 10, 10), sigma: 8),
      g('g4', const Rect.fromLTWH(80, 0, 10, 10), sigma: 8, aspect: 0.8),
    ], maxBlurs: 3);
    final passes = plan.single.passes;
    expect(passes, hasLength(3));
    expect(
      {for (final p in passes) p.blurSigma: p.groups},
      {
        1.1: ['g0', 'g1'],
        4: ['g2'],
        8: ['g3', 'g4'],
      },
    );
  });

  test('one blur per pass when uncapped keys fit', () {
    final plan = planGlassLayer([
      g('g0', const Rect.fromLTWH(0, 0, 10, 10), sigma: 1),
      g('g1', const Rect.fromLTWH(20, 0, 10, 10), sigma: 2),
    ], maxBlurs: 3);
    expect(plan.single.passes.map((p) => p.blurSigma), [1, 2]);
  });

  test('by default a stratum is one pass with the strongest blur', () {
    final plan = planGlassLayer([
      g('g0', const Rect.fromLTWH(0, 0, 10, 10), sigma: 1),
      g('g1', const Rect.fromLTWH(20, 0, 10, 10), sigma: 4, aspect: 0.9),
      g('g2', const Rect.fromLTWH(40, 0, 10, 10), sigma: 2),
    ]);
    final pass = plan.single.passes.single;
    expect(pass.blurSigma, 4);
    expect(pass.blurAspect, 0.9);
    expect(pass.groups, ['g0', 'g1', 'g2']);
  });

  test('different shader globals never share a pass', () {
    const dark = GlassBackdropConfig(
      spacing: 0,
      lightAngle: -2,
      devicePixelRatio: 2,
      constants: GlassConstants.standard,
      brightness: Brightness.dark,
      highContrast: false,
    );
    final plan = planGlassLayer([
      g('g0', const Rect.fromLTWH(0, 0, 10, 10)),
      g('g1', const Rect.fromLTWH(20, 0, 10, 10), config: dark),
    ]);
    expect(plan.single.passes, hasLength(2));
    expect(plan.single.passes[1].uniforms.brightness, Brightness.dark);
  });

  test('spacing travels per group', () {
    final plan = planGlassLayer([
      g('g0', const Rect.fromLTWH(0, 0, 10, 10), smoothing: 0),
      g('g1', const Rect.fromLTWH(20, 0, 10, 10), smoothing: 24),
    ]);
    final shapes = plan.single.passes.single.uniforms.shapes;
    expect(shapes.map((s) => s.smoothing), [0, 24]);
  });

  test('more than 24 shapes start another pass', () {
    final plan = planGlassLayer([
      for (var i = 0; i < 3; i++)
        g('g$i', Rect.fromLTWH(i * 100.0, 0, 50, 50), shapes: 10),
    ]);
    expect(plan.single.passes.map((p) => p.groups), [
      ['g0', 'g1'],
      ['g2'],
    ]);
  });

  test('the strongest glow wins a pass', () {
    final plan = planGlassLayer([
      g(
        'g0',
        const Rect.fromLTWH(0, 0, 10, 10),
        touch: const Offset(1, 1),
        glow: 0.2,
      ),
      g(
        'g1',
        const Rect.fromLTWH(20, 0, 10, 10),
        touch: const Offset(2, 2),
        glow: 0.7,
      ),
    ]);
    final u = plan.single.passes.single.uniforms;
    expect(u.touch, const Offset(2, 2));
    expect(u.glow, 0.7);
  });

  LayerGroupInput content(String id, Rect r, int order) => LayerGroupInput(
    id: id,
    order: [order],
    frame: null,
    bounds: r,
    config: _config,
    content: r,
  );

  test('content over earlier glass composites in its stratum, no pass', () {
    final plan = planGlassLayer([
      g('g0', const Rect.fromLTWH(0, 0, 100, 50)),
      content('row', const Rect.fromLTWH(10, 10, 80, 30), 1),
    ]);
    expect(plan.single.groups, ['g0', 'row']);
    expect(plan.single.passes.single.groups, ['g0']);
  });

  test('content follows the stratum of the glass it covers', () {
    final plan = planGlassLayer([
      g('g0', const Rect.fromLTWH(0, 0, 100, 100)),
      g('g1', const Rect.fromLTWH(10, 10, 50, 50)), // stratum 1
      content('label', const Rect.fromLTWH(20, 20, 10, 10), 2),
    ]);
    expect(plan.map((s) => s.groups), [
      ['g0'],
      ['g1', 'label'],
    ]);
  });

  test('glass over earlier content goes to the next stratum', () {
    final plan = planGlassLayer([
      content('text', const Rect.fromLTWH(0, 0, 100, 20), 0),
      g('g1', const Rect.fromLTWH(10, 0, 50, 50)),
    ]);
    expect(plan.map((s) => s.groups), [
      ['text'],
      ['g1'],
    ]);
  });
}

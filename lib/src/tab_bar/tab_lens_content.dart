import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'tab_lens.dart';
import 'tab_lens_program.dart';

/// The tab lens's content: [child] (the tinted tabs, unclipped) refracted
/// with the lens's displacement and clipped to [lens], drawn over the lens
/// glass. iOS lays the tinted tabs over the lens's brightened backdrop, so
/// they keep their colour while the backdrop lightens. Shows [fallback]
/// until the shader is loaded.
class TabLensContent extends StatelessWidget {
  /// Creates the lens content for a [box]-sized [child].
  const TabLensContent({
    super.key,
    required this.box,
    required this.lens,
    this.dispersion = tabLensContentDispersion,
    required this.fallback,
    required this.child,
  });

  /// Size of [child] (logical px).
  final Size box;

  /// The lens in [child]'s coordinates.
  final Rect lens;

  /// Colour split of the tabs (negative: red against green and blue, so
  /// blue tabs fringe in shades of blue).
  final double dispersion;

  /// Shown until the shader is available.
  final Widget fallback;

  /// The tinted tabs.
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<ui.FragmentProgram?>(
        valueListenable: TabLensProgram.instance.program,
        builder: (context, program, _) {
          if (program == null) return fallback;
          final shader = program.fragmentShader()
            ..setFloat(2, box.width)
            ..setFloat(3, box.height)
            ..setFloat(4, lens.center.dx)
            ..setFloat(5, lens.center.dy)
            ..setFloat(6, lens.width / 2)
            ..setFloat(7, lens.height / 2)
            ..setFloat(8, tabLensContentDecay)
            ..setFloat(9, tabLensContentBand)
            ..setFloat(10, tabLensContentStrength)
            ..setFloat(11, dispersion)
            // The tabs bend only at the lens's round ends: iOS's outward
            // push along the long sides moves the backdrop, not the tabs.
            ..setFloat(12, 0)
            ..setFloat(13, 1)
            ..setFloat(14, 1)
            ..setFloat(15, tabLensContentBlur);
          return IgnorePointer(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.shader(shader),
              child: SizedBox.fromSize(size: box, child: child),
            ),
          );
        },
      );
}

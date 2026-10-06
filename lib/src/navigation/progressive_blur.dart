import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'progressive_blur_program.dart';
import 'render_progressive_blur.dart';

/// A backdrop blur strongest at its top edge and sharp at its bottom.
///
/// Draws [fallback] instead while `progressive_blur.frag` is not loaded
/// (it starts loading on first build) or shader filters are unavailable
/// (Skia, web, widget tests).
class ProgressiveBlur extends StatelessWidget {
  /// Creates the blur.
  const ProgressiveBlur({
    super.key,
    required this.maxSigma,
    required this.falloff,
    required this.fallback,
  });

  /// The sigma at the top edge, logical px.
  final double maxSigma;

  /// The gradient's gamma: above 1 keeps the blur strong further down.
  final double falloff;

  /// Drawn when the shader cannot run.
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    if (!ui.ImageFilter.isShaderFilterSupported) return fallback;
    final programs = ProgressiveBlurProgram.instance;
    programs.load();
    return ValueListenableBuilder<ui.FragmentProgram?>(
      valueListenable: programs.program,
      builder: (context, program, _) => program == null
          ? fallback
          : _ProgressiveBlurLayer(
              program: program,
              maxSigma: maxSigma,
              falloff: falloff,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            ),
    );
  }
}

class _ProgressiveBlurLayer extends SingleChildRenderObjectWidget {
  const _ProgressiveBlurLayer({
    required this.program,
    required this.maxSigma,
    required this.falloff,
    required this.devicePixelRatio,
  }) : super(child: const SizedBox.expand());

  final ui.FragmentProgram program;
  final double maxSigma;
  final double falloff;
  final double devicePixelRatio;

  @override
  RenderProgressiveBlur createRenderObject(BuildContext context) =>
      RenderProgressiveBlur(
        program: program,
        maxSigma: maxSigma,
        falloff: falloff,
        devicePixelRatio: devicePixelRatio,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderProgressiveBlur renderObject,
  ) => renderObject
    ..program = program
    ..maxSigma = maxSigma
    ..falloff = falloff
    ..devicePixelRatio = devicePixelRatio;
}

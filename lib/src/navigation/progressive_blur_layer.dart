part of 'progressive_blur.dart';

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

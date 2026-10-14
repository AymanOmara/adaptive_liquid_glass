import 'dart:ui' as ui;

/// One fragment shader per render object, reused across paints.
///
/// A `FragmentShader` made on every paint and never disposed keeps its
/// native resources (and any image bound to a sampler) alive until the
/// Dart garbage collector finalises it. `ImageFilter.shader` copies the
/// uniforms and samplers when its native filter is made, so one shader can
/// be set up again and wrapped in a new filter every paint.
class ReusedShader<P extends Object, S extends Object> {
  /// Creates a holder that makes shaders with [create] and frees them with
  /// [release].
  ReusedShader({required this.create, required this.release});

  /// Makes a shader for a program.
  final S Function(P program) create;

  /// Frees a shader.
  final void Function(S shader) release;

  P? _program;
  S? _shader;

  /// The shader for [program]: the same one on every call until the
  /// program changes, when the old shader is released.
  S of(P program) {
    final shader = _shader;
    if (shader != null && identical(program, _program)) return shader;
    clear();
    _program = program;
    return _shader = create(program);
  }

  /// Releases the shader, if any.
  void clear() {
    final shader = _shader;
    _shader = null;
    _program = null;
    if (shader != null) release(shader);
  }
}

/// A [ReusedShader] for `dart:ui` fragment programs.
ReusedShader<ui.FragmentProgram, ui.FragmentShader> reusedFragmentShader() =>
    ReusedShader<ui.FragmentProgram, ui.FragmentShader>(
      create: (p) => p.fragmentShader(),
      release: (s) => s.dispose(),
    );

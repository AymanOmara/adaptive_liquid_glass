import 'package:flutter/painting.dart';

/// Where `FlutterFragCoord()` lives for a backdrop shader filter.
enum GlassTextureSpace {
  /// Screen physical px; `uSize` is the screen.
  global,

  /// Physical px relative to the filter's clip origin.
  local,
}

/// Measured by `example/integration_test/probe_test.dart`; see
/// `docs/superpowers/notes/shader-probe.md`.
///
/// Measured on iOS 26.4 / Impeller (Metal) for a `ClipRect` +
/// `BackdropFilter` placed directly in the scene, and for the same filter
/// inside an `Opacity` saveLayer whose subtree is offset from the screen
/// origin. In both cases, coordinates and `uSize` are relative to the root
/// render target (the screen, or a full-screen `toImage` at the origin),
/// not to the saveLayer or the filter clip. Not measured: `ShaderMask`,
/// `ColorFiltered`, route-transition `FadeTransition`, and rasterising a
/// subtree that is not at the origin into an image. In that last case the
/// image is the root target, so coordinates would be relative to it.
const GlassTextureSpace kGlassTextureSpace = GlassTextureSpace.global;

/// Maps a global logical rect into shader texture space.
Rect toTextureSpace(
  Rect globalLogical, {
  required Offset filterOriginGlobal,
  required double devicePixelRatio,
  GlassTextureSpace space = kGlassTextureSpace,
}) {
  final shifted = space == GlassTextureSpace.global
      ? globalLogical
      : globalLogical.shift(-filterOriginGlobal);
  return Rect.fromLTRB(
    shifted.left * devicePixelRatio,
    shifted.top * devicePixelRatio,
    shifted.right * devicePixelRatio,
    shifted.bottom * devicePixelRatio,
  );
}

/// Maps a global logical point into shader texture space.
Offset pointToTextureSpace(
  Offset globalLogical, {
  required Offset filterOriginGlobal,
  required double devicePixelRatio,
  GlassTextureSpace space = kGlassTextureSpace,
}) {
  final p = space == GlassTextureSpace.global
      ? globalLogical
      : globalLogical - filterOriginGlobal;
  return p * devicePixelRatio;
}

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

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../shader/glass_backdrop_config.dart';
import '../shader/glass_backdrop_debug_frame.dart';
import '../shader/glass_frame_uniforms.dart';
import '../shader/glass_texture_space.dart';

/// Most blurs (passes) one stratum draws per set of shader globals; past
/// it the closest sigmas merge and the larger wins. Each pass costs a
/// full-screen offscreen target under Impeller (measured: about 380 MB of
/// host graphics memory per extra pass on the emulator Gallery), so the
/// default is 1: a stratum of glass in one theme is one pass, and glass of
/// several sizes there shares the strongest frost. One group (or groups of
/// one size) keeps its exact blur.
/// `--dart-define=ADAPTIVE_LIQUID_GLASS_LAYER_BLURS=<n>` raises it.
const int kMaxPassesPerStratum = int.fromEnvironment(
  'ADAPTIVE_LIQUID_GLASS_LAYER_BLURS',
  defaultValue: 1,
);

/// One glass group as the shared layer sees it this frame.
@immutable
class LayerGroupInput {
  /// Creates an input.
  const LayerGroupInput({
    required this.id,
    required this.order,
    required this.frame,
    required this.bounds,
    required this.config,
    this.clip,
    this.opacity = 1,
    this.content,
  });

  /// The group (its renderer).
  final Object id;

  /// Paint-order path from the layer's common ancestor: child indices,
  /// compared lexicographically (a prefix paints first).
  final List<int> order;

  /// The group's frame (shapes in texture space, blur, touch); null for
  /// content that draws no glass (`GlassLayerContent`).
  final GlassBackdropDebugFrame? frame;

  /// The frame's clip bounds in global logical px (glass, shadow and merge
  /// margin).
  final Rect bounds;

  /// The group's drawing parameters.
  final GlassBackdropConfig config;

  /// Ancestor clip in global logical px; null is unbounded.
  final Rect? clip;

  /// Ancestor opacity, 0..1.
  final double opacity;

  /// The group's content (its renderer's box) in global logical px; null
  /// is the glass only.
  final Rect? content;

  /// [bounds] cut to [clip].
  Rect get region => clip == null ? bounds : bounds.intersect(clip!);

  Rect _cut(Rect r) => clip == null ? r : r.intersect(clip!);

  /// The glass bodies (no shadow), global logical px, cut to [clip].
  Rect get glass {
    final dpr = config.devicePixelRatio;
    final shapes = frame?.uniforms.shapes ?? const [];
    if (shapes.isEmpty) return Rect.zero;
    final r = shapes.map((s) => s.rect).reduce((a, b) => a.expandToInclude(b));
    return _cut(
      Rect.fromLTRB(r.left / dpr, r.top / dpr, r.right / dpr, r.bottom / dpr),
    );
  }

  /// The group's content, cut to [clip] (empty when unknown).
  Rect get contentRegion => content == null ? Rect.zero : _cut(content!);

  /// What this group puts on screen: its glass and its content.
  Rect get footprint {
    final g = glass;
    final c = contentRegion;
    if (c.isEmpty) return g;
    if (g.isEmpty) return c;
    return g.expandToInclude(c);
  }
}

/// One backdrop filter + shader pass.
@immutable
class LayerPass {
  /// Creates a pass.
  const LayerPass({
    required this.uniforms,
    required this.blurSigma,
    required this.blurAspect,
    required this.bounds,
    required this.groups,
  });

  /// What the shader draws (several groups).
  final GlassFrameUniforms uniforms;

  /// Composed blur sigma (logical px).
  final double blurSigma;

  /// sigmaX / [blurSigma].
  final double blurAspect;

  /// Clip of the pass in global logical px.
  final Rect bounds;

  /// The groups drawn, in paint order.
  final List<Object> groups;
}

/// Glass that draws after the content of every earlier stratum.
@immutable
class LayerStratum {
  /// Creates a stratum.
  const LayerStratum(this.passes, this.groups);

  /// Passes, drawn before [groups]' content.
  final List<LayerPass> passes;

  /// Groups whose content composites after [passes], in paint order.
  final List<Object> groups;
}

int _compareOrder(List<int> a, List<int> b) {
  for (var i = 0; i < math.min(a.length, b.length); i++) {
    final c = a[i].compareTo(b[i]);
    if (c != 0) return c;
  }
  return a.length.compareTo(b.length);
}

bool _overlaps(Rect a, Rect b) =>
    a.left < b.right &&
    b.left < a.right &&
    a.top < b.bottom &&
    b.top < a.bottom;

/// Shader globals that one pass shares: everything in the config but the
/// group spacing, which travels per shape.
@immutable
class _PassKey {
  const _PassKey(this.c);
  final GlassBackdropConfig c;

  @override
  bool operator ==(Object other) =>
      other is _PassKey &&
      other.c.lightAngle == c.lightAngle &&
      other.c.devicePixelRatio == c.devicePixelRatio &&
      other.c.constants == c.constants &&
      other.c.brightness == c.brightness &&
      other.c.highContrast == c.highContrast &&
      other.c.opaqueColor == c.opaqueColor;

  @override
  int get hashCode => Object.hash(
    c.lightAngle,
    c.devicePixelRatio,
    c.constants,
    c.brightness,
    c.highContrast,
    c.opaqueColor,
  );
}

/// Splits [groups] into strata and passes.
///
/// Groups go in paint order; each joins the stratum after the latest
/// earlier group whose glass or content its glass overlaps (so glass over glass, and glass
/// over another group's content, draws after it as before). Within a
/// stratum, groups sharing shader globals and blur draw in one pass of up
/// to [kMaxPassShapes] shapes; at most [maxBlurs] blurs per set of globals
/// (closest sigmas merge, the larger kept).
List<LayerStratum> planGlassLayer(
  List<LayerGroupInput> groups, {
  int maxBlurs = kMaxPassesPerStratum,
}) {
  final sorted = [
    for (final g in groups)
      if (g.opacity > 0 && !g.region.isEmpty) g,
  ]..sort((a, b) => _compareOrder(a.order, b.order));

  final level = <int>[];
  final strata = <List<LayerGroupInput>>[];
  for (var i = 0; i < sorted.length; i++) {
    var s = 0;
    final me = sorted[i];
    for (var j = 0; j < i; j++) {
      final them = sorted[j].footprint;
      // A later group's glass over an earlier group's glass or content
      // must draw after that content (the next stratum); its content over
      // them must composite no earlier than theirs. Shadows may overlap.
      if (_overlaps(me.glass, them)) {
        s = math.max(s, level[j] + 1);
      } else if (_overlaps(me.contentRegion, them)) {
        s = math.max(s, level[j]);
      }
    }
    level.add(s);
    while (strata.length <= s) {
      strata.add([]);
    }
    strata[s].add(sorted[i]);
  }

  return [
    for (final members in strata)
      LayerStratum(
        _passes([
          for (final g in members)
            if (g.frame != null) g,
        ], maxBlurs),
        [for (final g in members) g.id],
      ),
  ];
}

List<LayerPass> _passes(List<LayerGroupInput> members, int maxBlurs) {
  final byKey = <_PassKey, List<LayerGroupInput>>{};
  for (final g in members) {
    byKey.putIfAbsent(_PassKey(g.config), () => []).add(g);
  }
  final out = <LayerPass>[];
  for (final list in byKey.values) {
    final blurOf = _blurClusters(list, maxBlurs);
    final byBlur = <(double, double), List<LayerGroupInput>>{};
    for (final g in list) {
      byBlur.putIfAbsent(blurOf[g]!, () => []).add(g);
    }
    for (final MapEntry(key: blur, value: gs) in byBlur.entries) {
      var chunk = <LayerGroupInput>[];
      var count = 0;
      for (final g in gs) {
        final n = g.frame!.uniforms.shapes.length;
        if (count + n > kMaxPassShapes && chunk.isNotEmpty) {
          out.add(_pass(chunk, blur));
          chunk = [];
          count = 0;
        }
        chunk.add(g);
        count += n;
      }
      if (chunk.isNotEmpty) out.add(_pass(chunk, blur));
    }
  }
  return out;
}

/// Each group's (sigma, aspect), merged down to [maxBlurs] distinct values.
Map<LayerGroupInput, (double, double)> _blurClusters(
  List<LayerGroupInput> list,
  int maxBlurs,
) {
  final keys = <(double, double)>{
    for (final g in list) (g.frame!.blurSigma, g.frame!.blurAspect),
  }.toList()..sort((a, b) => a.$1.compareTo(b.$1));
  // Clusters of key indices; merge the closest neighbours (log sigma).
  final clusters = [
    for (var i = 0; i < keys.length; i++) [i],
  ];
  double logOf(int i) => math.log(math.max(keys[i].$1, 0) + 0.05);
  while (clusters.length > math.max(1, maxBlurs)) {
    var best = 0;
    var bestGap = double.infinity;
    for (var i = 0; i + 1 < clusters.length; i++) {
      final gap = logOf(clusters[i + 1].first) - logOf(clusters[i].last);
      if (gap < bestGap) {
        bestGap = gap;
        best = i;
      }
    }
    clusters[best].addAll(clusters.removeAt(best + 1));
  }
  final merged = <(double, double), (double, double)>{};
  for (final c in clusters) {
    // The largest sigma (and its aspect) wins.
    final top = keys[c.last];
    for (final i in c) {
      merged[keys[i]] = top;
    }
  }
  return {
    for (final g in list) g: merged[(g.frame!.blurSigma, g.frame!.blurAspect)]!,
  };
}

LayerPass _pass(List<LayerGroupInput> gs, (double, double) blur) {
  final first = gs.first;
  final dpr = first.config.devicePixelRatio;
  final shapes = [
    for (var i = 0; i < gs.length; i++)
      for (final s in gs[i].frame!.uniforms.shapes)
        s.inGroup(
          group: i,
          smoothing: gs[i].frame!.uniforms.smoothing,
          opacity: gs[i].opacity.clamp(0.0, 1.0),
          clip: gs[i].clip == null
              ? null
              : toTextureSpace(
                  gs[i].clip!,
                  filterOriginGlobal: Offset.zero,
                  devicePixelRatio: dpr,
                ),
        ),
  ];
  Offset? touch;
  var glow = 0.0;
  for (final g in gs) {
    final u = g.frame!.uniforms;
    if (u.touch != null && u.glow > glow) {
      glow = u.glow;
      touch = u.touch;
    }
  }
  final u0 = first.frame!.uniforms;
  return LayerPass(
    uniforms: GlassFrameUniforms(
      shapes: shapes,
      devicePixelRatio: dpr,
      lightAngle: u0.lightAngle,
      smoothing: u0.smoothing,
      constants: u0.constants,
      brightness: u0.brightness,
      highContrast: u0.highContrast,
      opaqueColor: u0.opaqueColor,
      touch: touch,
      glow: glow,
    ),
    blurSigma: blur.$1,
    blurAspect: blur.$2,
    bounds: gs.map((g) => g.region).reduce((a, b) => a.expandToInclude(b)),
    groups: [for (final g in gs) g.id],
  );
}

import 'dart:convert';

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/testing.dart';
import 'package:flutter/cupertino.dart' show CupertinoTheme, CupertinoThemeData;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'scene.dart';

/// A motion recording entry of `tool/scenes/motion.json` (Task 16).
class MotionSpec {
  /// Parses a motion entry.
  MotionSpec.fromJson(Map<String, Object?> j)
    : id = j['id']! as String,
      kind = j['kind']! as String,
      background = j['background']! as String,
      brightness = j['brightness'] == 'dark'
          ? Brightness.dark
          : Brightness.light,
      spacing = (j['spacing'] as num?)?.toDouble() ?? 0,
      shape = j['shape'] == null ? null : _shape(j['shape']),
      before = _shapes(j['before']),
      after = _shapes(j['after']);

  /// Motion id, used in launch arguments and recording names.
  final String id;

  /// `press` or `morph`.
  final String kind;

  /// Background asset name under `assets/backgrounds/`.
  final String background;

  /// Platform brightness the motion renders in.
  final Brightness brightness;

  /// Group spacing for morphs.
  final double spacing;

  /// The interactive shape of a press.
  final SceneShape? shape;

  /// Morph members before the tap, keyed by `glassId`.
  final Map<String, SceneShape> before;

  /// Morph members after the tap, keyed by `glassId`.
  final Map<String, SceneShape> after;

  static SceneShape _shape(Object? j) =>
      SceneShape.fromJson((j! as Map).cast<String, Object?>());

  static Map<String, SceneShape> _shapes(Object? j) => {
    for (final s in (j as List<Object?>?) ?? const <Object?>[])
      (s! as Map)['glassId']! as String: _shape(s),
  };
}

/// Runs the motion [id] from `assets/motion.json`; an unknown id shows a
/// magenta error screen and throws, like the static scene host.
///
/// [mode] defaults to the shader: that is what the motion harness fits
/// (`auto` means native glass on iOS 26).
Future<void> runMotion(
  String id,
  GlassConstants constants, {
  GlassRenderMode mode = GlassRenderMode.shader,
}) async {
  final j = jsonDecode(
    await rootBundle.loadString('assets/motion.json'),
  ) as Map<String, Object?>;
  final entry = (j['motion']! as List<Object?>)
      .cast<Map<Object?, Object?>>()
      .where((m) => m['id'] == id)
      .firstOrNull;
  if (entry == null) {
    runApp(
      const ColoredBox(
        color: Color(0xFFFF00FF),
        child: Center(
          child: Text(
            'MOTION FAILED: unknown -motion',
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: Color(0xFFFF0000),
              backgroundColor: Color(0xFFFFFFFF),
              fontSize: 24,
            ),
          ),
        ),
      ),
    );
    throw StateError('Unknown -motion $id');
  }
  runApp(
    LiquidGlassTheme(
      data: LiquidGlassThemeData(constants: constants, defaultMode: mode),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MotionView(
          spec: MotionSpec.fromJson(entry.cast<String, Object?>()),
        ),
      ),
    ),
  );
}

/// Renders a [MotionSpec]: the background, and either one interactive glass
/// shape (press) or a group whose members a background tap toggles between
/// `before` and `after` (morph).
class MotionView extends StatefulWidget {
  /// Creates the view for [spec].
  const MotionView({super.key, required this.spec});

  /// The motion to render.
  final MotionSpec spec;

  @override
  State<MotionView> createState() => _MotionViewState();
}

class _MotionViewState extends State<MotionView> {
  bool _toggled = false;

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    // Coordinates are physical screen positions shared with the SwiftUI
    // host, so `Positioned` is intentional here.
    Widget glass(SceneShape s, {Object? id, bool interactive = false}) =>
        Positioned.fromRect(
          key: id == null ? null : ValueKey(id),
          rect: s.rect,
          child: LiquidGlass(
            glass: interactive ? s.glass.interactive() : s.glass,
            shape: s.shape,
            glassId: id,
            child: const SizedBox.expand(),
          ),
        );
    final members = _toggled ? spec.after : spec.before;
    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(platformBrightness: spec.brightness),
      // Glass takes its appearance from the theme; follow the scene's.
      child: CupertinoTheme(
        data: CupertinoThemeData(brightness: spec.brightness),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: spec.kind == 'morph'
                    ? (_) => setState(() => _toggled = !_toggled)
                    : null,
                child: Image.asset(
                  'assets/backgrounds/${spec.background}.png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
              ),
            ),
            const Positioned(left: 0, top: 0, child: _Heartbeat()),
            if (spec.shape != null)
              Positioned.fill(
                child: Stack(children: [glass(spec.shape!, interactive: true)]),
              )
            else
              Positioned.fill(
                child: GlassGroup(
                  spacing: spec.spacing,
                  child: Stack(
                    children: [
                      for (final e in members.entries)
                        glass(e.value, id: e.key),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A 2 pt square at the top-left corner that changes every frame, like the
/// SwiftUI host's: it keeps the simulator's recorder and the engine from
/// idling before the touch (after an idle gap, recorded frames arrive with
/// compressed timestamps). It lies outside every motion crop.
class _Heartbeat extends StatefulWidget {
  const _Heartbeat();

  @override
  State<_Heartbeat> createState() => _HeartbeatState();
}

class _HeartbeatState extends State<_Heartbeat>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => setState(() => _elapsed = e))..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox.square(
      dimension: 2,
      child: ColoredBox(
        color: HSVColor.fromAHSV(
          1,
          (_elapsed.inMicroseconds % 1000000) / 1000000 * 360,
          1,
          1,
        ).toColor(),
      ),
    ),
  );
}

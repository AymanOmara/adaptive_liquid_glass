import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/material.dart';

/// `glassEffectTransition` demo: toggle glass in a [GlassGroup] under each
/// [GlassTransition]. `--dart-define=SHOW=true` starts with the glass shown
/// (for screenshots); `--dart-define=TRANSITION=materialize` picks one.
/// `flutter run -t lib/glass_transition_demo.dart`.
void main() => runApp(const _App());

const bool _startShown = bool.fromEnvironment('SHOW');
const String _startTransition = String.fromEnvironment(
  'TRANSITION',
  defaultValue: 'matchedGeometry',
);

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: GlassTransitionDemo(),
  );
}

/// The demo page.
class GlassTransitionDemo extends StatefulWidget {
  /// Creates the page.
  const GlassTransitionDemo({super.key});

  @override
  State<GlassTransitionDemo> createState() => _State();
}

class _State extends State<GlassTransitionDemo> {
  bool _shown = _startShown;
  GlassTransition _transition = GlassTransition.values.firstWhere(
    (t) => t.name == _startTransition,
    orElse: () => GlassTransition.matchedGeometry,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3A7BD5), Color(0xFFE96443)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _transition.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                GlassGroup(
                  spacing: 24,
                  child: SizedBox(
                    width: 300,
                    height: 72,
                    child: Stack(
                      children: [
                        const PositionedDirectional(
                          start: 0,
                          child: LiquidGlass(
                            glassId: 'a',
                            shape: GlassShape.circle(),
                            minSize: Size.square(72),
                            child: Icon(Icons.star),
                          ),
                        ),
                        if (_shown)
                          PositionedDirectional(
                            start: 114,
                            child: LiquidGlass(
                              glassId: 'b',
                              transition: _transition,
                              shape: const GlassShape.circle(),
                              minSize: const Size.square(72),
                              child: const Icon(Icons.favorite),
                            ),
                          ),
                        if (_shown)
                          PositionedDirectional(
                            start: 228,
                            child: LiquidGlass(
                              glassId: 'c',
                              transition: _transition,
                              shape: const GlassShape.circle(),
                              minSize: const Size.square(72),
                              child: const Icon(Icons.bolt),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SegmentedButton<GlassTransition>(
                  segments: [
                    for (final t in GlassTransition.values)
                      ButtonSegment(value: t, label: Text(t.name)),
                  ],
                  selected: {_transition},
                  onSelectionChanged: (s) =>
                      setState(() => _transition = s.first),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => setState(() => _shown = !_shown),
                  child: Text(_shown ? 'Hide' : 'Show'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/material.dart';

/// The README cookbook, one recipe per section, over a photo.
class Gallery extends StatelessWidget {
  /// Creates the gallery.
  const Gallery({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Gallery'),
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/backgrounds/photo.png', fit: BoxFit.cover),
          SafeArea(
            child: ListView(
              padding: const EdgeInsetsDirectional.all(20),
              children: const [
                _Recipe('Glass button', _GlassButton()),
                _Recipe('Card with padding', _Card()),
                _Recipe('Morphing pair (glassId)', _MorphingPair()),
                _Recipe('Merged union (unionId)', _Union()),
                _Recipe('Clear glass over media', _ClearOverMedia()),
                _Recipe('Tinted glass', _Tinted()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled gallery section.
class _Recipe extends StatelessWidget {
  const _Recipe(this.title, this.child);

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(blurRadius: 4)],
          ),
        ),
        const SizedBox(height: 12),
        Center(child: child),
      ],
    ),
  );
}

void _snack(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

class _GlassButton extends StatelessWidget {
  const _GlassButton();

  @override
  Widget build(BuildContext context) => LiquidGlass(
    onPressed: () => _snack(context, 'Pressed'),
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: 24,
      vertical: 14,
    ),
    child: const Text('Continue', style: TextStyle(fontSize: 17)),
  );
}

class _Card extends StatelessWidget {
  const _Card();

  @override
  Widget build(BuildContext context) => const LiquidGlass(
    shape: GlassShape.rect(24),
    padding: EdgeInsetsDirectional.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Liquid Glass',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 6),
        Text('Text and icons on glass pick a readable colour.'),
      ],
    ),
  );
}

class _MorphingPair extends StatefulWidget {
  const _MorphingPair();

  @override
  State<_MorphingPair> createState() => _MorphingPairState();
}

class _MorphingPairState extends State<_MorphingPair> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => GlassGroup(
    spacing: 20,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        LiquidGlass(
          glassId: 'toggle',
          shape: const GlassShape.circle(),
          padding: const EdgeInsetsDirectional.all(14),
          onPressed: () => setState(() => _expanded = !_expanded),
          child: Icon(_expanded ? Icons.close : Icons.add),
        ),
        if (_expanded)
          const LiquidGlass(
            glassId: 'extra',
            shape: GlassShape.circle(),
            padding: EdgeInsetsDirectional.all(14),
            child: Icon(Icons.favorite),
          ),
      ],
    ),
  );
}

class _Union extends StatelessWidget {
  const _Union();

  @override
  Widget build(BuildContext context) => GlassGroup(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 24,
      children: [
        for (final icon in [Icons.edit, Icons.share, Icons.delete])
          Icon(icon).glassEffect(
            shape: const GlassShape.circle(),
            unionId: 'tools',
            padding: const EdgeInsetsDirectional.all(12),
          ),
      ],
    ),
  );
}

class _ClearOverMedia extends StatelessWidget {
  const _ClearOverMedia();

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: SizedBox(
      height: 180,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/backgrounds/gradient.png', fit: BoxFit.cover),
          Center(
            child: const Icon(Icons.play_arrow, size: 36).glassEffect(
              glass: Glass.clear.interactive(),
              shape: const GlassShape.circle(),
              padding: const EdgeInsetsDirectional.all(16),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Tinted extends StatelessWidget {
  const _Tinted();

  @override
  Widget build(BuildContext context) => LiquidGlass(
    glass: Glass.regular.tint(Colors.blue),
    onPressed: () => _snack(context, 'Tinted'),
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: 24,
      vertical: 14,
    ),
    child: const Text('Tinted', style: TextStyle(fontSize: 17)),
  );
}

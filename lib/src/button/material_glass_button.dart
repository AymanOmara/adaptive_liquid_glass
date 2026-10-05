import 'package:flutter/material.dart';

import 'glass_button.dart';

/// Material 3 rendering of a [GlassButton].
class MaterialGlassButton extends StatelessWidget {
  /// Creates the Material button.
  const MaterialGlassButton({
    super.key,
    required this.button,
    required this.size,
  });

  /// The button to render.
  final GlassButton button;

  /// Its resolved size.
  final GlassControlSize size;

  @override
  Widget build(BuildContext context) => FilledButton.tonal(
    onPressed: button.active ? button.onPressed : null,
    child: button.child ?? Icon(button.icon),
  );
}

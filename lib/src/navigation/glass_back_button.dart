import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show BackButton, MaterialLocalizations;

import '../button/glass_button.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';

/// Whether a bar on this route should show a back button.
bool glassCanImplyBack(BuildContext context) =>
    ModalRoute.of(context)?.impliesAppBarDismissal ?? false;

/// iOS 26's back button: a circular glass chevron (mirrored in RTL) that
/// pops the route. A stock [BackButton] on the Material path.
class GlassBackButton extends StatelessWidget {
  /// Creates a back button.
  const GlassBackButton({super.key, this.onPressed, this.mode});

  /// Defaults to `Navigator.maybePop`.
  final VoidCallback? onPressed;

  /// Rendering mode; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) {
      final pop = onPressed ?? () => Navigator.maybePop(context);
      if (effective == EffectiveGlassMode.material) {
        return BackButton(onPressed: pop);
      }
      final label =
          Localizations.of<MaterialLocalizations>(
            context,
            MaterialLocalizations,
          )?.backButtonTooltip ??
          'Back';
      return GlassButton.icon(
        onPressed: pop,
        icon: CupertinoIcons.chevron_back,
        shape: GlassButtonShape.circle,
        mode: mode,
        semanticLabel: label,
      );
    },
  );
}

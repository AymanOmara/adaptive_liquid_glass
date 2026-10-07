import 'package:flutter/cupertino.dart';

import '../button/glass_button.dart';
import '../button/glass_button_shape.dart';
import '../button/glass_button_style.dart';
import '../button/glass_control_size.dart';
import '../core/glass_render_mode.dart';
import 'link_metrics.dart';

/// A SwiftUI `ShareLink(item:)`: a glass share trigger.
///
/// ```dart
/// GlassShareLink(onShare: () => Share.share(url))
/// GlassShareLink(label: 'Share', onShare: shareRecipe)
/// ```
///
/// The package does not present a share sheet itself: [onShare] is called on
/// tap and the app wires its share plugin. A null [onShare] disables the
/// trigger. Icon-only without [label], a capsule with text otherwise. Built
/// on [GlassButton.icon], so it joins an enclosing `GlassGroup` and is a
/// Material 3 button on the Material path. Assistive tech reads it as a
/// button labelled [semanticLabel] (default "Share" when icon-only).
class GlassShareLink extends StatelessWidget {
  /// Creates a share trigger.
  const GlassShareLink({
    super.key,
    required this.onShare,
    this.label,
    this.icon = LinkMetrics.shareIcon,
    this.style = GlassButtonStyle.glass,
    this.size,
    this.shape = GlassButtonShape.automatic,
    this.tint,
    this.mode,
    this.glassId,
    this.semanticLabel,
  });

  /// Called on tap; null disables the trigger.
  final VoidCallback? onShare;

  /// Text beside the glyph; null makes the trigger icon-only.
  final String? label;

  /// The glyph. Defaults to [LinkMetrics.shareIcon].
  final IconData icon;

  /// Plain or prominent glass.
  final GlassButtonStyle style;

  /// Defaults to the enclosing `GlassControlSizeScope`, else regular.
  final GlassControlSize? size;

  /// The outline.
  final GlassButtonShape shape;

  /// The prominent fill; defaults to the accent colour.
  final Color? tint;

  /// Rendering mode; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// Morph identity inside a `GlassGroup`.
  final Object? glassId;

  /// What assistive tech reads. Defaults to "Share" when icon-only, else
  /// to [label].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => GlassButton.icon(
    onPressed: onShare,
    icon: icon,
    label: label == null
        ? null
        : Text(
            label!,
            style: const TextStyle(fontWeight: LinkMetrics.labelWeight),
          ),
    style: style,
    size: size,
    shape: shape,
    tint: tint,
    mode: mode,
    glassId: glassId,
    semanticLabel: semanticLabel ?? (label == null ? 'Share' : null),
  );
}

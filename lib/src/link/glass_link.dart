import 'package:flutter/cupertino.dart';

import '../button/glass_button.dart';
import '../button/glass_button_shape.dart';
import '../button/glass_button_style.dart';
import '../button/glass_control_size.dart';
import '../core/glass_render_mode.dart';
import 'link_metrics.dart';

/// A SwiftUI `Link(destination:)`: a glass capsule that opens a URL.
///
/// ```dart
/// GlassLink(
///   destination: Uri.parse('https://flutter.dev'),
///   label: 'flutter.dev',
///   onOpen: launchUrl,
/// )
/// ```
///
/// The package does not open URLs itself: [onOpen] receives [destination]
/// and the app hands it to its launcher. A null [onOpen] disables the link.
/// Built on [GlassButton.icon], so it joins an enclosing `GlassGroup` and
/// is a Material 3 button on the Material path. Assistive tech reads it as
/// a link.
class GlassLink extends StatelessWidget {
  /// Creates a link.
  const GlassLink({
    super.key,
    required this.destination,
    required this.label,
    required this.onOpen,
    this.icon = LinkMetrics.linkIcon,
    this.style = GlassButtonStyle.glass,
    this.size,
    this.shape = GlassButtonShape.automatic,
    this.tint,
    this.mode,
    this.glassId,
    this.semanticLabel,
  });

  /// The URL to open.
  final Uri destination;

  /// The visible text.
  final String label;

  /// Called with [destination] on tap; null disables the link.
  final ValueChanged<Uri>? onOpen;

  /// The leading glyph; null hides it. Defaults to [LinkMetrics.linkIcon].
  final IconData? icon;

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

  /// Replaces [label] for assistive tech.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: const TextStyle(fontWeight: LinkMetrics.labelWeight),
    );
    final VoidCallback? onPressed = onOpen == null
        ? null
        : () => onOpen!(destination);
    final button = icon == null
        ? GlassButton(
            onPressed: onPressed,
            style: style,
            size: size,
            shape: shape,
            tint: tint,
            mode: mode,
            glassId: glassId,
            semanticLabel: semanticLabel,
            child: text,
          )
        : GlassButton.icon(
            onPressed: onPressed,
            icon: icon!,
            label: text,
            style: style,
            size: size,
            shape: shape,
            tint: tint,
            mode: mode,
            glassId: glassId,
            semanticLabel: semanticLabel,
          );
    // Merges into the button's node so it is read as a link to [destination].
    return MergeSemantics(
      child: Semantics(link: true, linkUrl: destination, child: button),
    );
  }
}

import 'package:flutter/cupertino.dart';

import '../core/cupertino_l10n.dart';
import '../core/glass_render_mode.dart';
import 'glass_popover_route.dart';
import 'popover_metrics.dart';

/// Shows an iOS 26 popover from the widget at [context], like SwiftUI's
/// `.popover` on iPhone with `.presentationCompactAdaptation(.popover)`:
/// a glass bubble opening over the anchor, without an arrow, the page
/// behind undimmed. A tap outside closes it.
///
/// ```dart
/// Builder(
///   builder: (context) => GlassButton.icon(
///     icon: CupertinoIcons.info,
///     semanticLabel: 'Info',
///     onPressed: () => showGlassPopover<void>(
///       context: context,
///       builder: (_) => const Padding(
///         padding: EdgeInsets.all(16),
///         child: Text('Liquid Glass popover'),
///       ),
///     ),
///   ),
/// )
/// ```
///
/// Its top is [overlap] below the anchor's top (SwiftUI's from a toolbar
/// button). The content sizes the bubble (give it its own padding). Completes with
/// the value the popover is popped with. On the Material path the bubble
/// is a Material surface. [semanticLabel] names the popover for assistive
/// tech; a tap outside, or the dismiss action, closes it.
Future<T?> showGlassPopover<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double overlap = PopoverMetrics.overlap,
  GlassRenderMode? mode,
  String? semanticLabel,
}) {
  final box = context.findRenderObject()! as RenderBox;
  final anchor = box.localToGlobal(Offset.zero) & box.size;
  final navigator = Navigator.of(context);
  return navigator.push(
    GlassPopoverRoute<T>(
      anchor: anchor,
      builder: builder,
      overlap: overlap,
      mode: mode,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      semanticLabel: semanticLabel,
      barrierLabel: cupertinoL10n(context).modalBarrierDismissLabel,
    ),
  );
}

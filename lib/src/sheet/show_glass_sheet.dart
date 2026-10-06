import 'package:flutter/material.dart';

import '../core/cupertino_l10n.dart';
import '../core/effective_glass_mode.dart';
import '../core/glass_render_mode.dart';
import '../core/render_mode_resolver.dart';
import '../core/theme.dart';
import '../platform/glass_platform.dart';
import 'glass_sheet_detent.dart';
import 'glass_sheet_route.dart';

/// Shows a modal iOS 26 sheet, like SwiftUI's `.sheet` with
/// `.presentationDetents`.
///
/// ```dart
/// showGlassSheet<void>(
///   context: context,
///   detents: const [GlassSheetDetent.medium, GlassSheetDetent.large],
///   builder: (context) => const Padding(
///     padding: EdgeInsets.all(20),
///     child: Text('Details'),
///   ),
/// );
/// ```
///
/// With [detents] the sheet rests at those heights and follows a vertical
/// drag between them: at a partial detent it is glass floating in from
/// the screen's edges; at [GlassSheetDetent.large] it runs edge to edge,
/// opaque, with the screen's corners. Without detents it is as tall as its
/// content. A tap outside, or a drag or fling down past the lowest detent,
/// dismisses it (unless [isDismissible] is false). It opens at
/// [initialDetent] (an index into [detents]). Completes with the value the
/// sheet is popped with.
///
/// On the Material path it is a Material 3 modal bottom sheet (scroll
/// controlled when [detents] has more than one height).
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  List<GlassSheetDetent> detents = const [],
  int initialDetent = 0,
  bool isDismissible = true,
  bool showGrabber = true,
  GlassRenderMode? mode,
}) {
  final effective = resolveGlassMode(
    requested: mode ?? LiquidGlassTheme.of(context).defaultMode,
    environment: GlassPlatform.instance.environment.value,
  );
  if (effective == EffectiveGlassMode.material) {
    return showModalBottomSheet<T>(
      context: context,
      builder: builder,
      isScrollControlled:
          detents.length > 1 || detents.contains(GlassSheetDetent.large),
      isDismissible: isDismissible,
      showDragHandle: showGrabber,
      useSafeArea: true,
    );
  }
  final navigator = Navigator.of(context);
  return navigator.push(
    GlassSheetRoute<T>(
      builder: builder,
      detents: detents,
      initialDetent: initialDetent,
      showGrabber: showGrabber,
      isDismissible: isDismissible,
      mode: mode,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      barrierLabel: cupertinoL10n(context).modalBarrierDismissLabel,
    ),
  );
}

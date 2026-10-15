import 'package:flutter/material.dart';

import '../core/cupertino_l10n.dart';
import '../core/effective_glass_mode.dart';
import '../core/glass_render_mode.dart';
import '../core/liquid_glass_theme.dart';
import '../core/render_mode_resolver.dart';
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
/// [cornerRadius] and [grabberSize] change the floating sheet's corners
/// and grabber (iOS 26's 38 and 34.67 x 5 by default).
///
/// [enableDrag] false keeps the sheet where it is: no drag between
/// detents and no drag or fling to dismiss. A tap outside is governed by
/// [isDismissible] alone.
///
/// [maxHeightFactor] caps the whole sheet, grabber and bottom inset
/// included, at that fraction of the screen's height: content taller
/// than the rest is constrained, and a detent above the cap rests at it.
///
/// On the Material path it is a Material 3 modal bottom sheet, scroll
/// controlled when [isScrollControlled] says so; null derives it (scroll
/// controlled when [detents] has more than one height or the large one,
/// or when [maxHeightFactor] is set, so the cap is the sheet's limit
/// rather than Material's 9/16). [enableDrag] and [maxHeightFactor] apply
/// there too. [cornerRadius] rounds its top corners; its drag handle
/// follows `BottomSheetThemeData.dragHandleSize` (Material 3's 32 x 4),
/// so [grabberSize] does not apply there.
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  List<GlassSheetDetent> detents = const [],
  int initialDetent = 0,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? isScrollControlled,
  double? maxHeightFactor,
  bool showGrabber = true,
  double? cornerRadius,
  Size? grabberSize,
  GlassRenderMode? mode,
}) {
  assert(
    maxHeightFactor == null || (maxHeightFactor > 0 && maxHeightFactor <= 1),
    'maxHeightFactor is a fraction of the screen height, in (0, 1].',
  );
  final effective = resolveGlassMode(
    requested: mode ?? LiquidGlassTheme.of(context).defaultMode,
    environment: GlassPlatform.instance.environment.value,
    highContrast: MediaQuery.highContrastOf(context),
  );
  if (effective == EffectiveGlassMode.material) {
    return showModalBottomSheet<T>(
      context: context,
      builder: builder,
      isScrollControlled:
          isScrollControlled ??
          (detents.length > 1 ||
              detents.contains(GlassSheetDetent.large) ||
              maxHeightFactor != null),
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      constraints: maxHeightFactor == null
          ? null
          : BoxConstraints(
              maxHeight: maxHeightFactor * MediaQuery.sizeOf(context).height,
            ),
      showDragHandle: showGrabber,
      shape: cornerRadius == null
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(cornerRadius),
              ),
            ),
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
      cornerRadius: cornerRadius,
      grabberSize: grabberSize,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      maxHeightFactor: maxHeightFactor,
      mode: mode,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      barrierLabel: cupertinoL10n(context).modalBarrierDismissLabel,
    ),
  );
}

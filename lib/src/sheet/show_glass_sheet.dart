import 'package:flutter/material.dart';

import '../core/effective_glass_mode.dart';
import '../core/glass_colors.dart';
import '../core/glass_render_mode.dart';
import '../core/render_mode_resolver.dart';
import '../core/theme.dart';
import '../platform/glass_platform.dart';
import 'glass_sheet.dart';

/// Shows a modal iOS 26 sheet: a [GlassSheet] floating up from the bottom.
///
/// ```dart
/// showGlassSheet<void>(
///   context: context,
///   builder: (context) => const Padding(
///     padding: EdgeInsets.all(20),
///     child: Text('Details'),
///   ),
/// );
/// ```
///
/// It is as tall as its content, up to about half the screen; with
/// [isScrollControlled] it may take the full height. Drag it down or tap
/// outside to dismiss. Needs a `MaterialApp` (or a `Navigator` with
/// Material localizations) above [context]. On the Material path it is a
/// Material 3 modal bottom sheet. Completes with the value the sheet is
/// popped with.
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
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
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      showDragHandle: showGrabber,
      useSafeArea: true,
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    useSafeArea: true,
    backgroundColor: GlassColors.transparent,
    barrierColor: GlassColors.sheetBarrier,
    elevation: 0,
    builder: (context) => GlassSheet(
      showGrabber: showGrabber,
      mode: mode,
      child: Builder(builder: builder),
    ),
  );
}

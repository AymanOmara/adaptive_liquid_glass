import 'package:flutter/material.dart';

import '../core/effective_glass_mode.dart';
import '../core/glass_render_mode.dart';
import '../core/render_mode_resolver.dart';
import '../core/theme.dart';
import '../platform/glass_platform.dart';
import 'glass_full_screen_cover_handle.dart';
import 'glass_full_screen_cover_route.dart';

/// Shows a full-screen modal cover, like SwiftUI's `.fullScreenCover`.
///
/// ```dart
/// final cover = showGlassFullScreenCover<void>(
///   context: context,
///   builder: (context) => Column(children: [
///     GlassButton(
///       onPressed: () => Navigator.pop(context),
///       child: const Text('Done'),
///     ),
///     const Expanded(child: PlayerView()),
///   ]),
/// );
/// // later: cover.dismiss();
/// ```
///
/// The cover is an opaque page sliding up from the bottom over the whole
/// screen; the page below neither scales nor dims. Its background runs
/// edge to edge while the content respects the safe area, and the status
/// bar picks a legible style for it. `Navigator.pop` from inside, or the
/// returned handle, closes it; with Reduce Motion it cross-fades instead
/// of sliding. On the Material path it is a Material 3 full-screen dialog
/// ([Dialog.fullscreen]).
GlassFullScreenCoverHandle<T> showGlassFullScreenCover<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  bool useRootNavigator = true,
  String? semanticLabel,
  GlassRenderMode? mode,
}) {
  final effective = resolveGlassMode(
    requested: mode ?? LiquidGlassTheme.of(context).defaultMode,
    environment: GlassPlatform.instance.environment.value,
  );
  final navigator = useRootNavigator
      ? Navigator.of(context, rootNavigator: true)
      : Navigator.of(context);
  final ModalRoute<T> route = effective == EffectiveGlassMode.material
      ? MaterialPageRoute<T>(
          fullscreenDialog: true,
          builder: (c) => Dialog.fullscreen(
            backgroundColor: backgroundColor,
            child: builder(c),
          ),
        )
      : GlassFullScreenCoverRoute<T>(
          builder: builder,
          backgroundColor: backgroundColor,
          semanticLabel: semanticLabel,
          capturedThemes: InheritedTheme.capture(
            from: context,
            to: navigator.context,
          ),
        );
  navigator.push(route);
  return GlassFullScreenCoverHandle<T>(route);
}

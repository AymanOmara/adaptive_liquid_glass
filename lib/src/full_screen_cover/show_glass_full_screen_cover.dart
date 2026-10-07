import 'package:flutter/material.dart';

import '../core/effective_glass_mode.dart';
import '../core/glass_render_mode.dart';
import '../core/render_mode_resolver.dart';
import '../core/theme.dart';
import '../platform/glass_platform.dart';
import 'full_screen_cover_drag.dart';
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
///
/// SwiftUI's cover has neither of these; both are off by default:
/// - [dragToDismiss] lets the cover be dragged down and released to close,
///   like iOS 26's sheet (a quarter of its height, or a fast fling;
///   otherwise it springs back). Vertical scrollables inside keep their
///   own drags. Assistive tech gets a dismiss action instead.
/// - [showsCloseButton] adds a close button in the top-trailing corner:
///   a glass xmark circle like iOS 26's `Button(role: .close)`, or a
///   Material close icon at the top-start corner on the Material path.
///   [closeButtonSemanticLabel] overrides its localized "Close".
///
/// Both close through `Navigator.maybePop`, so a `PopScope` can refuse.
GlassFullScreenCoverHandle<T> showGlassFullScreenCover<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  bool useRootNavigator = true,
  String? semanticLabel,
  bool dragToDismiss = false,
  bool showsCloseButton = false,
  String? closeButtonSemanticLabel,
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
          builder: (c) => FullScreenCoverDragDismiss(
            enabled: dragToDismiss,
            child: Dialog.fullscreen(
              backgroundColor: backgroundColor,
              child: showsCloseButton
                  ? Stack(
                      children: [
                        const SizedBox.expand(),
                        builder(c),
                        PositionedDirectional(
                          top: 0,
                          start: 0,
                          child: SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Builder(
                                builder: (c) => IconButton(
                                  icon: const Icon(Icons.close),
                                  tooltip:
                                      closeButtonSemanticLabel ??
                                      MaterialLocalizations.of(
                                        c,
                                      ).closeButtonTooltip,
                                  onPressed: () => Navigator.maybePop(c),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : builder(c),
            ),
          ),
        )
      : GlassFullScreenCoverRoute<T>(
          builder: builder,
          backgroundColor: backgroundColor,
          semanticLabel: semanticLabel,
          dragToDismiss: dragToDismiss,
          showsCloseButton: showsCloseButton,
          closeButtonSemanticLabel: closeButtonSemanticLabel,
          capturedThemes: InheritedTheme.capture(
            from: context,
            to: navigator.context,
          ),
        );
  navigator.push(route);
  return GlassFullScreenCoverHandle<T>(route);
}

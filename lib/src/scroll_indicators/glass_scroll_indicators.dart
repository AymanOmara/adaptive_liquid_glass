import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart' show Scrollbar;

import '../core/effective_glass_mode.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import 'glass_scroll_indicator_visibility.dart';
import 'scroll_indicator_metrics.dart';

/// Scroll indicators for the scrollable under it, as SwiftUI's
/// `.scrollIndicators(_:)`.
///
/// ```dart
/// GlassScrollIndicators(
///   visibility: GlassScrollIndicatorVisibility.visible,
///   child: ListView(children: rows),
/// )
/// ```
///
/// On the glass paths it draws UIKit's indicator: a thin bar that shows
/// while the content scrolls and fades out after
/// ([ScrollIndicatorMetrics]). On the Material path it uses Material's
/// [Scrollbar]. [GlassScrollIndicatorVisibility.hidden] and
/// [GlassScrollIndicatorVisibility.never] draw none, and also turn off the
/// default scrollbar Flutter adds on desktop.
///
/// Give it the scrollable's [controller] when the scrollable is not the
/// nearest one under it, or when the indicator is kept shown.
class GlassScrollIndicators extends StatelessWidget {
  /// Creates scroll indicators for [child].
  const GlassScrollIndicators({
    super.key,
    required this.child,
    this.visibility = GlassScrollIndicatorVisibility.automatic,
    this.controller,
    this.mode,
  });

  /// The scrollable.
  final Widget child;

  /// Whether the indicators show.
  final GlassScrollIndicatorVisibility visibility;

  /// The scrollable's controller.
  final ScrollController? controller;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// Whether the indicator stays shown: [GlassScrollIndicatorVisibility.visible]
  /// on a platform driven by a mouse or trackpad.
  bool get _persistent {
    if (visibility != GlassScrollIndicatorVisibility.visible) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Flutter's own desktop scrollbar would draw a second bar (or one
    // where none is wanted).
    final quiet = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: child,
    );
    if (!visibility.shows) return quiet;
    final persistent = _persistent;
    return GlassModeBuilder(
      mode: mode,
      builder: (context, mode) => mode == EffectiveGlassMode.material
          ? Scrollbar(
              controller: controller,
              thumbVisibility: persistent ? true : null,
              child: quiet,
            )
          : RawScrollbar(
              controller: controller,
              thumbVisibility: persistent,
              thickness: ScrollIndicatorMetrics.thickness,
              radius: ScrollIndicatorMetrics.radius,
              crossAxisMargin: ScrollIndicatorMetrics.crossAxisMargin,
              mainAxisMargin: ScrollIndicatorMetrics.mainAxisMargin,
              minThumbLength: ScrollIndicatorMetrics.minLength,
              timeToFade: ScrollIndicatorMetrics.timeToFade,
              fadeDuration: ScrollIndicatorMetrics.fadeDuration,
              // UIKit's indicator is not a drag handle.
              interactive: false,
              thumbColor: CupertinoDynamicColor.resolve(
                ScrollIndicatorMetrics.color,
                context,
              ),
              child: quiet,
            ),
    );
  }
}

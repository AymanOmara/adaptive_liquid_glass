import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;

import '../button/glass_control_size_scope.dart';
import '../core/effective_glass_mode.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/ios_text.dart';
import 'empty_state_metrics.dart';

/// iOS 26's empty state, like SwiftUI's `ContentUnavailableView`: a
/// centred icon, title, description and stacked actions where a list or a
/// search has nothing to show.
///
/// ```dart
/// GlassEmptyState(
///   icon: const Icon(CupertinoIcons.tray),
///   title: const Text('No Mail'),
///   description: const Text('New messages you receive will appear here.'),
///   actions: [GlassButton(onPressed: refresh, child: const Text('Refresh'))],
/// )
/// ```
///
/// `GlassEmptyState.search(query: controller.text)` is SwiftUI's
/// `ContentUnavailableView.search`. It draws no platter of its own: the
/// content sits plain over the page, and nothing animates. On the
/// Material path the same column takes Material 3 typography.
class GlassEmptyState extends StatelessWidget {
  /// Creates an empty state.
  const GlassEmptyState({
    super.key,
    required this.title,
    this.icon,
    this.description,
    this.actions = const [],
    this.mode,
  });

  /// Creates the search empty state, like
  /// `ContentUnavailableView.search(text:)`: a magnifying glass, "No
  /// Results" ("No Results for “query”" when [query] is given) and a hint
  /// to try again.
  factory GlassEmptyState.search({
    Key? key,
    String? query,
    List<Widget> actions = const [],
    GlassRenderMode? mode,
  }) => GlassEmptyState(
    key: key,
    icon: const Icon(CupertinoIcons.search),
    title: Text(
      query == null || query.isEmpty
          ? searchTitle
          : '$searchTitle for \u201C$query\u201D',
    ),
    description: const Text(searchDescription),
    actions: actions,
    mode: mode,
  );

  /// The `.search` variant's title without a query; build your own
  /// [GlassEmptyState] to localise it.
  static const String searchTitle = 'No Results';

  /// The `.search` variant's description; build your own [GlassEmptyState]
  /// to localise it.
  static const String searchDescription =
      'Check the spelling or try a new search.';

  /// The main text, e.g. "No Mail".
  final Widget title;

  /// The icon over the title, e.g. `Icon(CupertinoIcons.tray)`.
  final Widget? icon;

  /// The explanatory text under the title.
  final Widget? description;

  /// Buttons under the description, stacked vertically like iOS.
  final List<Widget> actions;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) => effective == EffectiveGlassMode.material
        ? _material(context)
        : _glass(context),
  );

  Widget _glass(BuildContext context) => _column(
    context,
    iconColor: CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    ),
    titleStyle: IOSText.style(
      EmptyStateMetrics.titleSize,
      weight: EmptyStateMetrics.titleWeight,
      color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
    ),
    descriptionStyle: IOSText.style(
      EmptyStateMetrics.descriptionSize,
      color: CupertinoDynamicColor.resolve(
        CupertinoColors.secondaryLabel,
        context,
      ),
    ),
  );

  Widget _material(BuildContext context) {
    final theme = Theme.of(context);
    return _column(
      context,
      iconColor: theme.colorScheme.onSurfaceVariant,
      titleStyle: theme.textTheme.titleLarge ?? const TextStyle(),
      descriptionStyle: (theme.textTheme.bodyMedium ?? const TextStyle())
          .copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }

  /// The centred column both paths share; only the styles differ.
  Widget _column(
    BuildContext context, {
    required Color iconColor,
    required TextStyle titleStyle,
    required TextStyle descriptionStyle,
  }) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: EmptyStateMetrics.horizontalPadding,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          ExcludeSemantics(
            child: IconTheme.merge(
              data: IconThemeData(
                size: EmptyStateMetrics.iconSize,
                color: iconColor,
              ),
              child: icon!,
            ),
          ),
          const SizedBox(height: EmptyStateMetrics.iconGap),
        ],
        Semantics(
          header: true,
          child: DefaultTextStyle(
            style: titleStyle,
            textAlign: TextAlign.center,
            child: title,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: EmptyStateMetrics.descriptionGap),
          DefaultTextStyle(
            style: descriptionStyle,
            textAlign: TextAlign.center,
            child: description!,
          ),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: EmptyStateMetrics.actionsGap),
          // SwiftUI sizes the actions' buttons small (measured: 15 pt
          // labels) unless the app set a control size.
          GlassControlSizeScope(
            size:
                GlassControlSizeScope.maybeOf(context) ??
                EmptyStateMetrics.actionsControlSize,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (final (i, action) in actions.indexed) ...[
                  if (i > 0)
                    const SizedBox(height: EmptyStateMetrics.actionSpacing),
                  action,
                ],
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

import 'package:flutter/cupertino.dart';

import '../core/ios_text.dart';
import '../list/list_metrics.dart';
import 'glass_search_suggestion.dart';
import 'search_metrics.dart';

/// One row of a [GlassSearchable]'s suggestions platter.
///
/// ```dart
/// GlassSearchSuggestionRow(
///   suggestion: suggestion,
///   onTap: () => controller.text = 'Copied Image',
/// )
/// ```
///
/// A leading slot, a title and a subtitle, on the searchable's platter
/// like a list row. The searchable copies the title into the field
/// before [GlassSearchSuggestion.onSelected] runs; tapping here only
/// forwards.
class GlassSearchSuggestionRow extends StatelessWidget {
  /// Creates a row.
  const GlassSearchSuggestionRow({
    super.key,
    required this.suggestion,
    required this.onTap,
  });

  /// The row's content.
  final GlassSearchSuggestion suggestion;

  /// Called when the row is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondary = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    return Semantics(
      container: true,
      button: true,
      label: suggestion.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: SearchMetrics.suggestionRowHeight,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ListMetrics.horizontalPadding,
              vertical: ListMetrics.verticalPadding,
            ),
            child: Row(
              children: [
                if (suggestion.leading != null) ...[
                  IconTheme.merge(
                    data: IconThemeData(
                      size: ListMetrics.iconSize,
                      color: secondary,
                    ),
                    child: suggestion.leading!,
                  ),
                  const SizedBox(width: ListMetrics.leadingGap),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DefaultTextStyle.merge(
                        style: IOSText.style(
                          ListMetrics.titleSize,
                          color: title,
                        ),
                        child: suggestion.title,
                      ),
                      if (suggestion.subtitle != null)
                        DefaultTextStyle.merge(
                          style: IOSText.style(
                            ListMetrics.subtitleSize,
                            color: secondary,
                          ),
                          child: suggestion.subtitle!,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

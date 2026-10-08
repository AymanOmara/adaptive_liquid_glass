import 'package:flutter/cupertino.dart';

import '../core/ios_text.dart';
import 'search_metrics.dart';

/// The "Cancel" label that ends an active [GlassSearchable]'s field.
///
/// ```dart
/// SearchCancelButton(onPressed: controller.cancel, label: 'Cancel')
/// ```
///
/// A body-size active-blue label over a widened touch target; the
/// searchable springs it in and out.
class SearchCancelButton extends StatelessWidget {
  /// Creates the button.
  const SearchCancelButton({
    super.key,
    required this.onPressed,
    required this.label,
  });

  /// Called when the label is tapped.
  final VoidCallback onPressed;

  /// The label, usually the localized "Cancel".
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: SearchMetrics.cancelMinWidth,
        ),
        child: Center(
          // The semantic label above replaces the visible one.
          child: ExcludeSemantics(
            child: Text(
              label,
              style: IOSText.style(
                SearchMetrics.cancelFontSize,
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.activeBlue,
                  context,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

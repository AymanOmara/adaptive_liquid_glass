import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/effective_glass_mode.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../sheet/glass_sheet_detent.dart';
import '../sheet/show_glass_sheet.dart';
import 'inspector_metrics.dart';

/// SwiftUI's `.inspector(isPresented:content:)` (iOS 26): supplementary
/// content beside [child] that shows and hides with [isPresented].
///
/// ```dart
/// GlassInspector(
///   isPresented: showDetails,
///   onPresentedChanged: (shown) => setState(() => showDetails = shown),
///   inspector: (context) => const DetailsForm(),
///   child: const NotesList(),
/// )
/// ```
///
/// At regular width (at least [regularWidth], an iPad or a wide window)
/// the inspector is a trailing column [width] wide that slides in beside
/// [child], which narrows to make room; trailing follows the reading
/// direction, so in right-to-left text it is on the left. At compact
/// width (an iPhone) it is a sheet at [detents], as iOS 26 presents it.
/// Resizing across the breakpoint moves an open inspector between the two.
///
/// [isPresented] is the source of truth: the owner flips it, and
/// [onPresentedChanged] reports false when the user swipes or taps the
/// sheet away, so the owner can keep it in step (as SwiftUI's binding
/// does). On the Material path the column is a Material 3 surface and
/// the sheet a modal bottom sheet.
class GlassInspector extends StatefulWidget {
  /// An [inspector] beside [child].
  const GlassInspector({
    super.key,
    required this.isPresented,
    required this.inspector,
    required this.child,
    this.onPresentedChanged,
    this.width = InspectorMetrics.columnWidth,
    this.regularWidth = InspectorMetrics.regularWidth,
    this.detents = const [GlassSheetDetent.large],
    this.backgroundColor,
    this.mode,
  });

  /// Whether the inspector shows.
  final bool isPresented;

  /// Builds the inspector's content, in the column or the sheet.
  final WidgetBuilder inspector;

  /// The main content.
  final Widget child;

  /// Called with false when the user dismisses the sheet.
  final ValueChanged<bool>? onPresentedChanged;

  /// The trailing column's width at regular width.
  final double width;

  /// The narrowest width that shows a column rather than a sheet.
  final double regularWidth;

  /// The sheet's detents at compact width; large only by default, as
  /// iOS 26 opens a compact inspector.
  final List<GlassSheetDetent> detents;

  /// The column's background; iOS's grouped background (or Material's
  /// low surface container) by default.
  final Color? backgroundColor;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  State<GlassInspector> createState() => _GlassInspectorState();
}

class _GlassInspectorState extends State<GlassInspector> {
  /// Whether the last layout was compact.
  bool _compact = false;

  /// The open sheet's route, once its builder has run.
  ModalRoute<Object?>? _route;

  /// The navigator the sheet was pushed on.
  NavigatorState? _navigator;

  /// A sheet is pushed and has not completed.
  bool _open = false;

  /// The sheet is being closed by [isPresented], not by the user.
  bool _closing = false;

  bool _syncScheduled = false;

  @override
  void didUpdateWidget(GlassInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPresented != widget.isPresented) _scheduleSync();
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  void _scheduleSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (mounted) _sync();
    });
  }

  /// Opens or closes the sheet to match [GlassInspector.isPresented].
  void _sync() {
    final want = widget.isPresented && _compact;
    if (want && !_open) {
      _open = true;
      _closing = false;
      _navigator = Navigator.of(context);
      showGlassSheet<void>(
        context: context,
        detents: widget.detents,
        mode: widget.mode,
        builder: (sheetContext) {
          if (_route == null) {
            _route = ModalRoute.of(sheetContext);
            // Closed before the sheet built: close it now.
            if (mounted) _scheduleSync();
          }
          return widget.inspector(sheetContext);
        },
      ).then((_) {
        final byUser = !_closing;
        _open = false;
        _closing = false;
        _route = null;
        _navigator = null;
        if (byUser && mounted && widget.isPresented) {
          widget.onPresentedChanged?.call(false);
        }
      });
    } else if (!want && _open) {
      _close();
    }
  }

  void _close() {
    final route = _route;
    final navigator = _navigator;
    if (route == null || navigator == null || _closing) return;
    _closing = true;
    if (route.isCurrent) {
      navigator.pop();
    } else if (route.isActive) {
      navigator.removeRoute(route);
    }
  }

  Widget _column(BuildContext context, EffectiveGlassMode mode) {
    final material = mode == EffectiveGlassMode.material;
    final background =
        widget.backgroundColor ??
        (material
            ? Theme.of(context).colorScheme.surfaceContainerLow
            : CupertinoDynamicColor.resolve(
                CupertinoColors.systemGroupedBackground,
                context,
              ));
    final separator = material
        ? Theme.of(context).colorScheme.outlineVariant
        : CupertinoDynamicColor.resolve(GlassColors.listSeparator, context);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final shown = widget.isPresented;
    return AnimatedContainer(
      duration: reduceMotion ? Duration.zero : InspectorMetrics.columnAnimation,
      curve: Curves.easeInOut,
      width: shown ? widget.width : 0,
      child: ClipRect(
        child: OverflowBox(
          alignment: AlignmentDirectional.centerStart,
          minWidth: widget.width,
          maxWidth: widget.width,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              border: BorderDirectional(
                start: BorderSide(
                  color: separator,
                  width: InspectorMetrics.separatorWidth,
                ),
              ),
            ),
            child: ExcludeFocus(
              excluding: !shown,
              child: ExcludeSemantics(
                excluding: !shown,
                child: Builder(builder: widget.inspector),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < widget.regularWidth;
        if (compact != _compact) {
          _compact = compact;
          _scheduleSync();
        } else if (widget.isPresented != _open && compact) {
          _scheduleSync();
        }
        if (compact) return widget.child;
        return GlassModeBuilder(
          mode: widget.mode,
          builder: (context, mode) {
            final media = MediaQuery.of(context);
            return Row(
              children: [
                Expanded(
                  // The column covers the trailing safe area.
                  child: widget.isPresented
                      ? MediaQuery(
                          data: media.removePadding(
                            removeLeft:
                                Directionality.of(context) == TextDirection.rtl,
                            removeRight:
                                Directionality.of(context) == TextDirection.ltr,
                          ),
                          child: widget.child,
                        )
                      : widget.child,
                ),
                _column(context, mode),
              ],
            );
          },
        );
      },
    );
  }
}

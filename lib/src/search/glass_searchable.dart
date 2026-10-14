import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        ButtonSegment,
        Durations,
        Easing,
        ListTile,
        SearchAnchor,
        SegmentedButton;
import 'package:flutter/physics.dart';

import '../controls/glass_segment.dart';
import '../controls/glass_segmented_control.dart';
import '../core/cupertino_l10n.dart';
import '../core/effective_glass_mode.dart';
import '../core/glass.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../list/list_metrics.dart';
import 'glass_search_controller.dart';
import 'glass_search_field.dart';
import 'glass_search_suggestion.dart';
import 'glass_search_suggestion_row.dart';
import 'glass_searchable_placement.dart';
import 'search_cancel_button.dart';
import 'search_metrics.dart';

/// iOS 26's `.searchable` presentation: a [GlassSearchField] that takes
/// the screen's focus, a close button that slides out from its end,
/// suggestions listed in place of the content and scope segments.
///
/// ```dart
/// GlassSearchable(
///   controller: search,
///   scopes: const ['All', 'Mine'],
///   suggestionsBuilder: (context, search) =>
///       results(search.text).map(GlassSearchSuggestion.new).toList(),
///   child: const MailList(),
/// )
/// ```
///
/// Activating the field (which happens on focus) reveals Cancel with a
/// spring, the scopes and the suggestions; Cancel clears the field and
/// dismisses them. [GlassSearchablePlacement] picks iPhone's bottom field
/// or iPad's navigation-bar one. On the Material path it is a Material 3
/// [SearchAnchor] with a [SegmentedButton] for scopes.
///
/// It composes with a scaffold rather than slotting into one: wrap the
/// `GlassScaffold` body (the field then floats over the content, above the
/// scaffold's bars with the bottom placement) and keep the scaffold's own
/// bars and accessory as they are.
class GlassSearchable extends StatefulWidget {
  /// Creates a searchable presentation over [child].
  const GlassSearchable({
    super.key,
    required this.child,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.suggestionsBuilder,
    this.scopes,
    this.onScopeChanged,
    this.placement = GlassSearchablePlacement.bottom,
    this.placeholder,
    this.cancelLabel,
    this.semanticLabel,
    this.glass,
    this.mode,
  }) : assert(
         scopes == null || scopes.length >= 2,
         'Scopes need at least two entries.',
       );

  /// The screen content the search presents over.
  final Widget child;

  /// The search state; one is made when null.
  final GlassSearchController? controller;

  /// Called as the field's text changes, including when Cancel clears it.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits from the keyboard.
  final ValueChanged<String>? onSubmitted;

  /// Builds the suggestions for the controller's current text, listed in
  /// place of the content while search is active, as SwiftUI does. An
  /// empty list draws none.
  final List<GlassSearchSuggestion> Function(
    BuildContext context,
    GlassSearchController controller,
  )?
  suggestionsBuilder;

  /// The scopes, as labels for a segmented control under the field while
  /// active. Null draws none.
  final List<String>? scopes;

  /// Called with the scope's index when the user picks one.
  final ValueChanged<int>? onScopeChanged;

  /// Where the field sits; see [GlassSearchablePlacement].
  final GlassSearchablePlacement placement;

  /// The text shown while the field is empty. Defaults to the localized
  /// "Search".
  final String? placeholder;

  /// The Cancel button's label. Defaults to the localized "Cancel".
  final String? cancelLabel;

  /// What assistive tech reads for the field; see
  /// [GlassSearchField.semanticLabel].
  final String? semanticLabel;

  /// The glass of the field.
  final Glass? glass;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  State<GlassSearchable> createState() => _GlassSearchableState();
}

class _GlassSearchableState extends State<GlassSearchable>
    with TickerProviderStateMixin {
  GlassSearchController? _own;

  GlassSearchController get _controller =>
      widget.controller ?? (_own ??= GlassSearchController());

  /// The field's focus, activation's trigger.
  final FocusNode _focusNode = FocusNode();

  /// 0 with Cancel hidden, 1 shown; a spring in between.
  late final AnimationController _reveal;

  /// Whether search is active, as last seen from the controller.
  bool _wasActive = false;

  /// Whether the Cancel button is in the tree; it leaves once fully
  /// hidden.
  bool _cancelMounted = false;

  /// Whether the Material path's search view is open; its scopes then sit
  /// in the view rather than under the bar it covers.
  bool _viewOpen = false;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController.unbounded(vsync: this);
    _wasActive = _controller.isActive;
    _reveal.value = _wasActive ? 1 : 0;
    _cancelMounted = _reveal.value > 0;
    _reveal.addListener(_revealChanged);
    _controller.addListener(_controllerChanged);
    _focusNode.addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(GlassSearchable old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _own)?.removeListener(_controllerChanged);
      _own?.dispose();
      _own = null;
      _wasActive = _controller.isActive;
      _reveal.value = _wasActive ? 1 : 0;
      _cancelMounted = _reveal.value > 0;
      _controller.addListener(_controllerChanged);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_focusChanged);
    _focusNode.dispose();
    _reveal.removeListener(_revealChanged);
    _reveal.dispose();
    _controller.removeListener(_controllerChanged);
    _own?.dispose();
    super.dispose();
  }

  /// Activation follows the field's focus.
  void _focusChanged() {
    if (_focusNode.hasFocus) _controller.activate();
  }

  /// Reacts to the controller, external calls included: drives the Cancel
  /// reveal and rebuilds for the text, scopes and suggestions.
  void _controllerChanged() {
    if (_controller.isActive != _wasActive) {
      _wasActive = _controller.isActive;
      _spring(_reveal, SearchMetrics.activation, _wasActive ? 1 : 0);
      if (!_wasActive) {
        _focusNode.unfocus();
        // An outside cancel ends the Material path's open view too.
        final text = _controller.textController;
        if (_viewOpen && text.isAttached && text.isOpen) text.closeView(null);
      }
    }
    setState(() {});
  }

  /// The Cancel button leaves the tree once fully hidden; the spring also
  /// lands exactly on its end, so the last frame drops the button from
  /// layout, hit-testing and semantics.
  void _revealChanged() {
    if (!_reveal.isAnimating) {
      final end = _wasActive ? 1.0 : 0.0;
      if (_reveal.value != end) _reveal.value = end;
    }
    if (_cancelMounted != _reveal.value > 0) {
      setState(() => _cancelMounted = _reveal.value > 0);
    }
  }

  /// Runs [c] to [target] with [s], or jumps there under Reduce Motion.
  void _spring(AnimationController c, SpringDescription s, double target) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      c.value = target;
    } else {
      c.animateWith(SpringSimulation(s, c.value, target, c.velocity));
    }
  }

  void _cancel() {
    _controller.cancel();
    _focusNode.unfocus();
    widget.onChanged?.call('');
  }

  void _scopeChanged(int index) {
    _controller.scopeIndex = index;
    widget.onScopeChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: widget.mode,
    builder: (context, effective) => effective == EffectiveGlassMode.material
        ? _material(context)
        : _glass(context),
  );

  Widget _glass(BuildContext context) {
    final suggestions = _wasActive && widget.suggestionsBuilder != null
        ? widget.suggestionsBuilder!(context, _controller)
        : const <GlassSearchSuggestion>[];
    final scopes = _wasActive ? widget.scopes : null;
    if (widget.placement == GlassSearchablePlacement.navigationBar) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Below the status bar and Dynamic Island.
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              SearchMetrics.inset,
              MediaQuery.paddingOf(context).top + SearchMetrics.verticalInset,
              SearchMetrics.inset,
              SearchMetrics.verticalInset,
            ),
            child: _fieldRow(context),
          ),
          if (scopes != null) _scopeBar(inset: true),
          Expanded(
            // The field above has taken the top inset.
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  widget.child,
                  if (suggestions.isNotEmpty)
                    Positioned.fill(
                      child: _suggestionList(context, suggestions),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    // SwiftUI (iOS 26.4, measured) shows the scopes once a query is typed,
    // as a bar at the top under the status bar that pushes the content
    // down; suggestions replace the content with a plain list.
    final topScopes = scopes != null && _controller.text.isNotEmpty;
    final media = MediaQuery.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (topScopes)
          MediaQuery(
            data: media.copyWith(
              padding: media.padding.copyWith(
                top: media.padding.top + SearchMetrics.scopeContentShift,
              ),
            ),
            child: widget.child,
          )
        else
          widget.child,
        if (suggestions.isNotEmpty)
          Positioned.fill(child: _suggestionList(context, suggestions)),
        if (topScopes && suggestions.isEmpty)
          PositionedDirectional(
            top: media.padding.top + SearchMetrics.scopeTop,
            start: SearchMetrics.scopeInset,
            end: SearchMetrics.scopeInset,
            child: _scopeSegments(),
          ),
        AnimatedBuilder(
          animation: _reveal,
          // Idle, SwiftUI floats the field like the toolbar (28 pt from
          // the screen's sides and bottom); active, it widens to 12 pt
          // from the sides and sits 12 pt above the keyboard.
          builder: (context, child) {
            final side = lerpDouble(
              SearchMetrics.idleInset,
              SearchMetrics.inset,
              _reveal.value.clamp(0.0, 1.0),
            )!;
            return PositionedDirectional(
              start: side,
              end: side,
              bottom: math.max(
                SearchMetrics.idleBottom,
                MediaQuery.viewInsetsOf(context).bottom +
                    SearchMetrics.verticalInset,
              ),
              child: child!,
            );
          },
          child: _fieldRow(context),
        ),
      ],
    );
  }

  /// The field and, while any part of it shows, Cancel sliding out from
  /// the end.
  Widget _fieldRow(BuildContext context) => Row(
    children: [
      Expanded(
        child: GlassSearchField(
          controller: _controller.textController,
          focusNode: _focusNode,
          placeholder: widget.placeholder,
          semanticLabel: widget.semanticLabel,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          glass: widget.glass,
          mode: widget.mode,
        ),
      ),
      if (_cancelMounted)
        AnimatedBuilder(
          animation: _reveal,
          builder: (context, _) {
            // iOS 26.4 (measured, `-controls search` tapped): the field
            // narrows first, then the close button grows in place from
            // about a third of its size as it fades in.
            final t = _reveal.value.clamp(0.0, 1.0);
            final slot = (t / SearchMetrics.revealSplit).clamp(0.0, 1.0);
            final grow =
                ((t - SearchMetrics.revealSplit) /
                        (1 - SearchMetrics.revealSplit))
                    .clamp(0.0, 1.0);
            return ClipRect(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: slot,
                child: Opacity(
                  opacity: grow,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: SearchMetrics.cancelGap,
                    ),
                    child: Transform.scale(
                      scale: lerpDouble(SearchMetrics.revealScale, 1, grow),
                      child: SearchCancelButton(
                        onPressed: _cancel,
                        label:
                            widget.cancelLabel ??
                            cupertinoL10n(context).cancelButtonLabel,
                        mode: widget.mode,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
    ],
  );

  /// The scope segments under the field; [inset] gives them the field's
  /// horizontal inset, the navigation-bar placement's.
  Widget _scopeBar({required bool inset}) => Padding(
    padding: EdgeInsetsDirectional.only(
      start: inset ? SearchMetrics.inset : 0,
      end: inset ? SearchMetrics.inset : 0,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: SearchMetrics.scopeGap),
        _scopeSegments(),
      ],
    ),
  );

  Widget _scopeSegments() => GlassSegmentedControl<int>(
    segments: [
      for (final (i, scope) in widget.scopes!.indexed)
        GlassSegment(value: i, label: Text(scope)),
    ],
    selected: _controller.scopeIndex,
    onChanged: _scopeChanged,
    mode: widget.mode,
  );

  /// The suggestions as SwiftUI shows them (iOS 26.4, measured): a plain
  /// list on the system background in place of the content, from under
  /// the status bar, a separator above, between and below the rows.
  Widget _suggestionList(
    BuildContext context,
    List<GlassSearchSuggestion> items,
  ) {
    final separator = ColoredBox(
      color: CupertinoDynamicColor.resolve(GlassColors.listSeparator, context),
      child: const SizedBox(
        height: ListMetrics.separatorThickness,
        width: double.infinity,
      ),
    );
    final padded = Padding(
      padding: const EdgeInsetsDirectional.only(
        start: ListMetrics.horizontalPadding,
        end: ListMetrics.separatorEnd,
      ),
      child: separator,
    );
    return ColoredBox(
      color: CupertinoDynamicColor.resolve(
        CupertinoColors.systemBackground,
        context,
      ),
      child: ListView(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        children: [
          padded,
          for (final item in items) ...[_row(item), padded],
        ],
      ),
    );
  }

  Widget _row(GlassSearchSuggestion suggestion) => GlassSearchSuggestionRow(
    suggestion: suggestion,
    onTap: () {
      final title = suggestion.title;
      if (title is Text && title.data != null) {
        _controller.text = title.data!;
      }
      suggestion.onSelected?.call();
    },
  );

  /// The Material view opening is activation, as focus is on the glass
  /// path.
  void _viewOpened() {
    _viewOpen = true;
    _controller.activate();
  }

  /// Closing the view with an empty field ends search; with a query it
  /// stays active, its scopes under the bar, until the field is cleared.
  void _viewClosed() {
    setState(() => _viewOpen = false);
    if (_controller.isActive && _controller.text.isEmpty) _controller.cancel();
  }

  /// The Material scope buttons, following the controller so the copy in
  /// the search view's route updates too.
  Widget _scopeButtons() => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => SegmentedButton<int>(
      segments: [
        for (final (i, scope) in widget.scopes!.indexed)
          ButtonSegment(value: i, label: Text(scope)),
      ],
      selected: {_controller.scopeIndex},
      onSelectionChanged: (selection) => _scopeChanged(selection.first),
    ),
  );

  Widget _material(BuildContext context) {
    final scopes = widget.scopes;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            SearchMetrics.inset,
            SearchMetrics.verticalInset,
            SearchMetrics.inset,
            SearchMetrics.verticalInset,
          ),
          child: SearchAnchor.bar(
            searchController: _controller.textController,
            barHintText:
                widget.placeholder ??
                cupertinoL10n(context).searchTextFieldPlaceholderLabel,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            onOpen: _viewOpened,
            onClose: _viewClosed,
            viewBuilder: scopes == null
                ? null
                : (suggestions) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.all(
                          SearchMetrics.inset,
                        ),
                        child: _scopeButtons(),
                      ),
                      Expanded(
                        child: MediaQuery.removePadding(
                          context: context,
                          removeTop: true,
                          child: ListView(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.viewInsetsOf(context).bottom,
                            ),
                            children: suggestions.toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
            suggestionsBuilder: (context, controller) => [
              for (final suggestion
                  in widget.suggestionsBuilder?.call(context, _controller) ??
                      const <GlassSearchSuggestion>[])
                ListTile(
                  title: suggestion.title,
                  subtitle: suggestion.subtitle,
                  leading: suggestion.leading,
                  onTap: () {
                    final title = suggestion.title;
                    final text = title is Text ? title.data : null;
                    if (text != null) controller.closeView(text);
                    _controller.text = text ?? _controller.text;
                    suggestion.onSelected?.call();
                  },
                ),
            ],
          ),
        ),
        // Like the glass path, scopes show only while search is active.
        AnimatedSize(
          duration: reduceMotion ? Duration.zero : Durations.medium2,
          curve: Easing.standard,
          alignment: AlignmentDirectional.topCenter,
          child: scopes != null && _wasActive && !_viewOpen
              ? Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    SearchMetrics.inset,
                    0,
                    SearchMetrics.inset,
                    SearchMetrics.verticalInset,
                  ),
                  child: _scopeButtons(),
                )
              : const SizedBox(width: double.infinity),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}

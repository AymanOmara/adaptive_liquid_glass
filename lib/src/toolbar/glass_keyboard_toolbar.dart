import 'package:flutter/material.dart';

import '../adaptive/glass_adaptive.dart';
import '../core/glass_render_mode.dart';
import 'glass_toolbar_row.dart';
import 'glass_toolbar_spacer.dart';
import 'keyboard_toolbar_metrics.dart';

/// iOS 26's keyboard toolbar (`ToolbarItemGroup(placement: .keyboard)`):
/// bar items in glass capsules resting on the software keyboard while a
/// text field inside [child] has focus.
///
/// ```dart
/// GlassKeyboardToolbar(
///   children: [
///     GlassButton.icon(onPressed: previous, icon: CupertinoIcons.chevron_up,
///         semanticLabel: 'Previous'),
///     GlassButton.icon(onPressed: next, icon: CupertinoIcons.chevron_down,
///         semanticLabel: 'Next'),
///     const GlassToolbarSpacer(),
///     GlassButton(onPressed: FocusScope.of(context).unfocus,
///         child: const Text('Done')),
///   ],
///   child: Column(children: [GlassTextField(...), GlassTextField(...)]),
/// )
/// ```
///
/// Items group into capsules as in `GlassToolbar`. The bar follows the
/// keyboard's live height (whether or not the `Scaffold` resizes), rides
/// down with it when the keyboard is dismissed, and fades out when focus
/// moves to a field outside [child] (at once under Reduce Motion). It is
/// shown through an `OverlayPortal`, so it needs an `Overlay` above it
/// (any `MaterialApp`, `CupertinoApp` or `Navigator` gives one).
///
/// Measured from SwiftUI (`KeyboardToolbarMetrics`). On the Material path
/// it is a full-width surface bar on the keyboard, with the same items.
class GlassKeyboardToolbar extends StatefulWidget {
  /// Creates a keyboard toolbar for the fields in [child].
  const GlassKeyboardToolbar({
    super.key,
    required this.children,
    required this.child,
    this.mode,
  });

  /// The items, usually `GlassButton.icon`s and a "Done" `GlassButton`,
  /// with [GlassToolbarSpacer]s between groups.
  final List<Widget> children;

  /// The content whose text fields show the bar while focused.
  final Widget child;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  State<GlassKeyboardToolbar> createState() => _GlassKeyboardToolbarState();
}

class _GlassKeyboardToolbarState extends State<GlassKeyboardToolbar>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _portal = OverlayPortalController();
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  )..addStatusListener(_onFadeStatus);

  /// Focus is inside [GlassKeyboardToolbar.child], or left it without
  /// going to another field (the keyboard is going down: ride with it).
  bool _active = false;

  /// Focus is inside [GlassKeyboardToolbar.child] right now.
  bool _focusInside = false;
  double _keyboard = 0;

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _keyboard = _keyboardOf(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fade.dispose();
    super.dispose();
  }

  /// The keyboard's height from the view itself: a resizing `Scaffold`
  /// removes it from the `MediaQuery` its body sees.
  static double _keyboardOf(BuildContext context) =>
      MediaQueryData.fromView(View.of(context)).viewInsets.bottom;

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final keyboard = _keyboardOf(context);
    if (keyboard == _keyboard) return;
    setState(() => _keyboard = keyboard);
    _update();
  }

  void _onFocusChange(bool focused) {
    if (focused) {
      _active = true;
    } else {
      // Focus went to another text field: that field's keyboard is not
      // ours. Otherwise the keyboard is going down; ride it out.
      final next = FocusManager.instance.primaryFocus?.context;
      final toField =
          next != null &&
          (next.widget is EditableText ||
              next.findAncestorWidgetOfExactType<EditableText>() != null);
      if (toField) _active = false;
    }
    _update();
  }

  void _update() {
    if (_keyboard <= 0) _active = _active && _focusInside;
    final show = _active && _keyboard > 0;
    if (show) {
      if (!_portal.isShowing) _portal.show();
      if (_reduceMotion) {
        _fade.value = 1;
      } else {
        _fade.forward();
      }
    } else if (_portal.isShowing) {
      if (_reduceMotion || _keyboard <= 0) {
        _fade.value = 0;
      } else {
        _fade.reverse();
      }
    }
  }

  void _onFadeStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _portal.isShowing) {
      // Not during a build: the status can change inside one.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _fade.isDismissed && _portal.isShowing) _portal.hide();
      });
    }
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _portal,
    overlayChildBuilder: _bar,
    child: Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        _focusInside = focused;
        _onFocusChange(focused);
      },
      child: widget.child,
    ),
  );

  Widget _bar(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: Padding(
      padding: EdgeInsets.only(
        bottom:
            _keyboard +
            (GlassAdaptive.usesGlass(context, mode: widget.mode)
                ? KeyboardToolbarMetrics.gap
                : 0),
      ),
      child: FadeTransition(
        opacity: _fade,
        child: GlassAdaptive(
          mode: widget.mode,
          glass: GlassToolbarRow(
            single: KeyboardToolbarMetrics.single,
            grouped: KeyboardToolbarMetrics.grouped,
            height: KeyboardToolbarMetrics.height,
            edgeInset: KeyboardToolbarMetrics.edgeInset,
            mode: widget.mode,
            children: widget.children,
          ),
          material: _materialBar,
        ),
      ),
    ),
  );

  Widget _materialBar(BuildContext context) => Material(
    key: KeyboardToolbarMetrics.materialBarKey,
    color: Theme.of(context).colorScheme.surfaceContainer,
    child: SizedBox(
      height: KeyboardToolbarMetrics.materialHeight,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
        child: Row(
          children: [
            for (final child in widget.children)
              child is GlassToolbarSpacer ? const Spacer() : child,
          ],
        ),
      ),
    ),
  );
}

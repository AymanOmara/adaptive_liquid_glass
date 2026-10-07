import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        ExpansibleController,
        ExpansionTile,
        MaterialBasedCupertinoThemeData,
        Theme;
import 'package:flutter/physics.dart' show SpringSimulation;

import '../core/effective_glass_mode.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/ios_text.dart';
import '../core/swiftui_spring.dart';
import '../interaction/glass_pressable.dart';
import '../list/glass_list_tile.dart';
import '../list/list_metrics.dart';
import 'disclosure_chevron.dart';
import 'disclosure_metrics.dart';
import 'disclosure_separator_scope.dart';

/// iOS 26's disclosure group, like SwiftUI's `DisclosureGroup` in an
/// inset-grouped list: a row that reveals more rows beneath it.
///
/// ```dart
/// GlassListSection(children: [
///   GlassDisclosureGroup(
///     label: const Text('Advanced'),
///     children: [
///       GlassListTile(title: const Text('Proxy'), value: 'Off'),
///       GlassListTile(title: const Text('DNS'), value: 'Automatic'),
///     ],
///   ),
/// ])
/// ```
///
/// The label row lays out as a [GlassListTile] row whose label-coloured
/// chevron rotates to point down while the children spring open,
/// indented like SwiftUI's. A section separates only its direct
/// children, so the group draws its own hairlines between the label row
/// and the children, and below itself. On the Material path it is a
/// Material 3 [ExpansionTile].
class GlassDisclosureGroup extends StatefulWidget {
  /// Creates a disclosure group.
  const GlassDisclosureGroup({
    super.key,
    required this.label,
    required this.children,
    this.leading,
    this.isExpanded,
    this.onExpansionChanged,
    this.initiallyExpanded = false,
    this.enabled = true,
    this.semanticLabel,
    this.mode,
  });

  /// The row's title, like [GlassListTile.title].
  final Widget label;

  /// The rows revealed when expanded, usually [GlassListTile]s.
  final List<Widget> children;

  /// The row's start icon, with [GlassListTile.leading]'s treatment.
  final Widget? leading;

  /// The group's state while controlled; null keeps the state internal.
  final bool? isExpanded;

  /// Called with the new state when the row is tapped.
  final ValueChanged<bool>? onExpansionChanged;

  /// Whether the group starts expanded; used only while uncontrolled.
  final bool initiallyExpanded;

  /// Whether the row responds to taps; a disabled row dims.
  final bool enabled;

  /// What assistive tech reads for the row, over the label's text.
  final String? semanticLabel;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  State<GlassDisclosureGroup> createState() => _GlassDisclosureGroupState();
}

class _GlassDisclosureGroupState extends State<GlassDisclosureGroup>
    with SingleTickerProviderStateMixin {
  /// The group's own state while uncontrolled.
  late bool _internalExpanded;

  /// The expand/collapse progress: 0 collapsed, 1 expanded.
  late final AnimationController _controller;

  /// The Material path's expansion state.
  late final ExpansibleController _material;

  /// The children's share of the animation, clamped for the size and
  /// opacity fades.
  late final Animation<double> _sizeFactor = _ClampedAnimation(_controller);

  /// Whether the children are in the tree; they stay mounted while any
  /// part of them shows and leave once fully collapsed.
  late bool _childrenMounted;

  /// Whether a pointer is down on the row.
  bool _pressed = false;

  /// The row's state: the parent's while controlled, else the group's
  /// own.
  bool get _expanded => widget.isExpanded ?? _internalExpanded;

  /// Whether the expand/collapse jumps rather than animates.
  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    _internalExpanded = widget.initiallyExpanded;
    _controller = AnimationController(vsync: this, value: _expanded ? 1 : 0);
    _childrenMounted = _controller.value > 0;
    _controller.addListener(_synced);
    _material = ExpansibleController();
  }

  @override
  void didUpdateWidget(GlassDisclosureGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasExpanded = oldWidget.isExpanded ?? _internalExpanded;
    if (_expanded != wasExpanded) {
      _animateTo(_expanded);
      if (widget.isExpanded != null) {
        widget.isExpanded! ? _material.expand() : _material.collapse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _material.dispose();
    super.dispose();
  }

  /// The children stay mounted while the animation shows any of them and
  /// leave the tree once fully collapsed. The spring also lands exactly
  /// on its end, so the chevron rests square and the last frame drops
  /// the children from hit-testing and semantics.
  void _synced() {
    if (!_controller.isAnimating) {
      final end = _expanded ? 1.0 : 0.0;
      if (_controller.value != end) _controller.value = end;
    }
    if (_childrenMounted != _controller.value > 0) {
      setState(() => _childrenMounted = _controller.value > 0);
    }
  }

  void _toggle() {
    if (!widget.enabled) return;
    widget.onExpansionChanged?.call(!_expanded);
    if (widget.isExpanded == null) {
      setState(() => _internalExpanded = !_internalExpanded);
      _animateTo(_internalExpanded);
    }
  }

  /// Runs the expansion to [target] with a SwiftUI spring, or jumps
  /// straight there under Reduce Motion.
  void _animateTo(bool target) {
    final end = target ? 1.0 : 0.0;
    if (_reduceMotion) {
      _controller.value = end;
      return;
    }
    final spring = swiftUISpring(
      response: DisclosureMetrics.springResponse,
      dampingFraction: DisclosureMetrics.springDamping,
    );
    _controller.animateWith(
      SpringSimulation(spring, _controller.value, end, 0),
    );
  }

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: widget.mode,
    builder: (context, effective) => effective == EffectiveGlassMode.material
        ? _materialTile()
        : _glass(context),
  );

  Widget _materialTile() => ExpansionTile(
    controller: _material,
    title: widget.label,
    leading: widget.leading,
    initiallyExpanded: _expanded,
    onExpansionChanged: widget.enabled ? _materialChanged : null,
    enabled: widget.enabled,
    children: widget.children,
  );

  /// The tile toggles itself eagerly on a tap, while the parent owns the
  /// state while controlled; an unadopted value is undone after the
  /// frame.
  void _materialChanged(bool value) {
    if (widget.isExpanded != null) {
      if (value == widget.isExpanded) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.isExpanded == null) return;
        widget.isExpanded! ? _material.expand() : _material.collapse();
      });
    } else {
      setState(() => _internalExpanded = value);
    }
    widget.onExpansionChanged?.call(value);
  }

  Widget _glass(BuildContext context) {
    final separatorColor = CupertinoDynamicColor.resolve(
      GlassColors.listSeparator,
      context,
    );
    final labelStart = widget.leading != null
        ? ListMetrics.textStart
        : ListMetrics.horizontalPadding;
    final group = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _childrenMounted
            ? _withSeparator(_labelRow(context), labelStart, separatorColor)
            : _labelRow(context),
        if (_childrenMounted)
          SizeTransition(
            sizeFactor: _sizeFactor,
            alignment: AlignmentDirectional.topStart,
            child: FadeTransition(
              opacity: _sizeFactor,
              child: _childrenRows(separatorColor),
            ),
          ),
      ],
    );
    if (!DisclosureSeparatorScope.of(context)) return group;
    // A section left the hairline below to the group: under the label
    // while collapsed, under the last indented child while open.
    final children = widget.children;
    return _withSeparator(
      group,
      _childrenMounted && children.isNotEmpty
          ? DisclosureMetrics.childIndent + _separatorStart(children.last)
          : labelStart,
      separatorColor,
    );
  }

  /// The children, indented, with a hairline overlaid on each row's
  /// bottom edge but the last's, as the section separates its own rows.
  /// The hairlines start at the indented title.
  Widget _childrenRows(Color separatorColor) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < widget.children.length; i++)
        i < widget.children.length - 1
            ? _withSeparator(
                _indented(widget.children[i]),
                DisclosureMetrics.childIndent +
                    _separatorStart(widget.children[i]),
                separatorColor,
              )
            : _indented(widget.children[i]),
    ],
  );

  /// A child row shifted toward the end by SwiftUI's disclosure indent;
  /// its trailing content stays put.
  Widget _indented(Widget row) => Padding(
    padding: const EdgeInsetsDirectional.only(
      start: DisclosureMetrics.childIndent,
    ),
    child: row,
  );

  /// A separator's start inset below a row: the title's start when the
  /// row has a leading, else the row's own inset.
  double _separatorStart(Widget row) =>
      row is GlassListTile && row.leading != null
      ? ListMetrics.textStart
      : ListMetrics.horizontalPadding;

  /// Overlays the hairline on a row's bottom edge, adding no height, as
  /// `GlassListSection` separates its rows.
  Widget _withSeparator(Widget row, double start, Color color) => Stack(
    children: [
      row,
      PositionedDirectional(
        start: start,
        end: ListMetrics.separatorEnd,
        bottom: 0,
        height: ListMetrics.separatorThickness,
        child: ColoredBox(color: color),
      ),
    ],
  );

  /// The leading's tint: iOS 26's list accent, the theme's primary
  /// colour when customized, or a dim grey while disabled.
  Color _leadingColor(BuildContext context) {
    if (!widget.enabled) {
      return CupertinoDynamicColor.resolve(GlassColors.tertiaryLabel, context);
    }
    final theme = CupertinoTheme.of(context);
    // Under a MaterialApp the Cupertino theme is derived from the
    // Material colour scheme, whose primary is not an iOS accent choice;
    // only an explicit cupertinoOverrideTheme colour counts there.
    final Color? primary = theme is MaterialBasedCupertinoThemeData
        ? Theme.of(context).cupertinoOverrideTheme?.primaryColor
        : theme.primaryColor;
    // CupertinoTheme.of resolves dynamic colours, so compare against the
    // resolved default blue, not the activeBlue constant itself.
    final defaultBlue = CupertinoDynamicColor.resolve(
      GlassColors.listDefaultAccent,
      context,
    );
    if (primary == null || primary == defaultBlue) {
      return CupertinoDynamicColor.resolve(GlassColors.listIcon, context);
    }
    return CupertinoDynamicColor.resolve(primary, context);
  }

  Widget _labelRow(BuildContext context) {
    final title = CupertinoDynamicColor.resolve(
      widget.enabled ? GlassColors.label : GlassColors.tertiaryLabel,
      context,
    );
    // SwiftUI draws the disclosure chevron in the label colour, not the
    // accent (measured: 0, 0, 0 on white).
    final chevronColor = CupertinoDynamicColor.resolve(
      widget.enabled ? GlassColors.label : GlassColors.tertiaryLabel,
      context,
    );
    // Collapsed the chevron points toward the end; expanded it points
    // down, turning the mirrored way in RTL.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final turns = Tween<double>(
      begin: 0,
      end: (rtl ? -1.0 : 1.0) * DisclosureMetrics.expandedTurns,
    ).animate(_controller);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: ListMetrics.minRowHeight),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: widget.leading != null
              ? ListMetrics.leadingStart
              : ListMetrics.horizontalPadding,
          end: DisclosureMetrics.chevronEnd,
          top: ListMetrics.verticalPadding,
          bottom: ListMetrics.verticalPadding,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.leading != null) ...[
              SizedBox(
                width: ListMetrics.leadingWidth,
                child: Center(
                  child: IconTheme.merge(
                    data: IconThemeData(
                      size: ListMetrics.iconSize,
                      color: _leadingColor(context),
                    ),
                    child: widget.leading!,
                  ),
                ),
              ),
              const SizedBox(width: ListMetrics.leadingGap),
            ],
            Expanded(
              child: DefaultTextStyle.merge(
                style: IOSText.style(ListMetrics.titleSize, color: title),
                child: widget.label,
              ),
            ),
            const SizedBox(width: ListMetrics.trailingGap),
            DisclosureChevron(color: chevronColor, turns: turns),
          ],
        ),
      ),
    );
    final highlighted = Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: _pressed
                ? CupertinoDynamicColor.resolve(
                    GlassColors.listRowPressed,
                    context,
                  )
                : GlassColors.transparent,
          ),
        ),
        row,
      ],
    );
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: widget.enabled,
        expanded: _expanded,
        label: widget.semanticLabel,
        child: GestureDetector(
          // The highlight follows the tap gesture, and the semantics
          // above carry the expanded state, so the detector stays out of
          // the semantics tree.
          excludeFromSemantics: true,
          onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
          onTapUp: widget.enabled ? (_) => _setPressed(false) : null,
          onTapCancel: widget.enabled ? () => _setPressed(false) : null,
          child: GlassPressable(
            onPressed: widget.enabled ? _toggle : null,
            child: widget.semanticLabel == null
                ? highlighted
                : ExcludeSemantics(child: highlighted),
          ),
        ),
      ),
    );
  }
}

/// The parent's value clamped to 0..1, so no spring overshoot could
/// reach SizeTransition or FadeTransition.
class _ClampedAnimation extends ProxyAnimation {
  _ClampedAnimation(super.parent);

  @override
  double get value => super.value.clamp(0.0, 1.0);
}

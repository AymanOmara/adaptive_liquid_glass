import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        ColorScheme,
        Icons,
        ListTile,
        ListTileTheme,
        Material,
        StadiumBorder,
        Theme;
import 'package:flutter/physics.dart' show SpringSimulation;

import '../core/effective_glass_mode.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/ios_text.dart';
import '../core/swiftui_spring.dart';
import '../disclosure/disclosure_chevron.dart';
import '../disclosure/disclosure_metrics.dart';
import '../split_view/glass_split_view.dart';
import '../tab_bar/tab_sidebar_metrics.dart';
import 'glass_list_tile.dart';
import 'list_metrics.dart';
import 'sidebar_column_scope.dart';
import 'sidebar_metrics.dart';

/// How a [GlassSidebarList] lays out.
enum GlassSidebarLayout {
  /// Regular inside a side-by-side [GlassSplitView] sidebar, compact
  /// everywhere else.
  automatic,

  /// iPhone's sidebar list: rows on inset-grouped platters under
  /// collapsible headers.
  compact,

  /// iPad's sidebar column: rows straight on the sidebar's glass, the
  /// selection a rounded fill.
  regular,
}

/// A row of a [GlassSidebarSection]: a destination the sidebar selects.
@immutable
class GlassSidebarItem<T> {
  /// Creates a sidebar row.
  const GlassSidebarItem({
    required this.value,
    required this.title,
    this.icon,
    this.badge,
    this.enabled = true,
    this.semanticLabel,
  });

  /// The value [GlassSidebarList.onSelectionChanged] reports, and that
  /// [GlassSidebarList.selection] matches to highlight the row.
  final T value;

  /// The row's label, usually a [Text].
  final Widget title;

  /// The row's start icon, drawn in the label colour as SwiftUI's
  /// `Label` in a sidebar.
  final Widget? icon;

  /// A count or short text at the row's end, like a mailbox's unread
  /// count.
  final String? badge;

  /// Whether the row can be selected; a disabled row dims.
  final bool enabled;

  /// What assistive tech reads for the row, over the title's text.
  final String? semanticLabel;
}

/// A section of a [GlassSidebarList]: a header that collapses its rows.
@immutable
class GlassSidebarSection<T> {
  /// Creates a sidebar section.
  const GlassSidebarSection({
    this.header,
    required this.items,
    this.isExpanded,
    this.onExpansionChanged,
    this.initiallyExpanded = true,
    this.collapsible = true,
  });

  /// The section's title, usually a [Text]; null for a section without
  /// a header (which then cannot collapse).
  final Widget? header;

  /// The section's rows.
  final List<GlassSidebarItem<T>> items;

  /// The section's state while controlled; null keeps it internal.
  final bool? isExpanded;

  /// Called with the new state when the header is tapped.
  final ValueChanged<bool>? onExpansionChanged;

  /// Whether the section starts expanded; used only while uncontrolled.
  final bool initiallyExpanded;

  /// Whether the header shows a disclosure chevron and toggles the rows,
  /// as SwiftUI's `Section(isExpanded:)`.
  final bool collapsible;
}

/// iOS 26's sidebar list, like SwiftUI's `List(selection:)` with
/// `.listStyle(.sidebar)`: sections of selectable rows under headers
/// that collapse them.
///
/// ```dart
/// GlassSidebarList<String>(
///   selection: mailbox,
///   onSelectionChanged: (value) => setState(() => mailbox = value),
///   sections: const [
///     GlassSidebarSection(
///       header: Text('Library'),
///       items: [
///         GlassSidebarItem(
///           value: 'inbox',
///           title: Text('Inbox'),
///           icon: Icon(CupertinoIcons.tray),
///         ),
///         GlassSidebarItem(
///           value: 'sent',
///           title: Text('Sent'),
///           icon: Icon(CupertinoIcons.paperplane),
///         ),
///       ],
///     ),
///   ],
/// )
/// ```
///
/// At compact width (iPhone) the rows sit on inset-grouped platters and
/// the selected row fills grey edge to edge; each header carries a
/// label-coloured chevron that springs the platter open and shut. As a
/// [GlassSplitView]'s sidebar at regular width (iPad) the rows lie on the
/// sidebar's glass and the selection is a rounded fill, as
/// [GlassTabBarStyle.sidebarAdaptable]'s sidebar; at compact width a
/// selection there also pushes the split view's next column. On the
/// Material path it is a navigation-drawer list with expandable headers.
class GlassSidebarList<T> extends StatelessWidget {
  /// Creates a sidebar list.
  const GlassSidebarList({
    super.key,
    required this.sections,
    this.selection,
    this.onSelectionChanged,
    this.layout = GlassSidebarLayout.automatic,
    this.controller,
    this.padding,
    this.backgroundColor,
    this.physics,
    this.primary,
    this.mode,
  });

  /// The list's sections, top to bottom.
  final List<GlassSidebarSection<T>> sections;

  /// The selected row's value; null selects none.
  final T? selection;

  /// Called with a row's value when it is tapped. A [GlassSplitView]
  /// above at compact width also shows its next column.
  final ValueChanged<T>? onSelectionChanged;

  /// Which layout to use; see [GlassSidebarLayout].
  final GlassSidebarLayout layout;

  /// The list's scroll controller.
  final ScrollController? controller;

  /// Padding inside the scroll view, added to the safe area; null uses
  /// the measured insets.
  final EdgeInsetsGeometry? padding;

  /// The page behind a compact list; null uses iOS's grouped background
  /// (a regular list paints none, over the sidebar's glass).
  final Color? backgroundColor;

  /// The list's scroll physics.
  final ScrollPhysics? physics;

  /// Whether this is the primary scroll view; see [ScrollView.primary].
  final bool? primary;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  bool _regular(BuildContext context) => switch (layout) {
    GlassSidebarLayout.compact => false,
    GlassSidebarLayout.regular => true,
    GlassSidebarLayout.automatic =>
      SidebarColumnScope.maybeOf(context)?.regular ?? false,
  };

  void _select(BuildContext context, T value) {
    onSelectionChanged?.call(value);
    final column = SidebarColumnScope.maybeOf(context);
    if (column != null && !column.regular) {
      GlassSplitView.maybeOf(context)?.showColumn(column.next);
    }
  }

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) {
      final material = effective == EffectiveGlassMode.material;
      final regular = !material && _regular(context);
      final media = MediaQuery.of(context);
      final insets =
          (padding ??
                  EdgeInsets.only(
                    top: regular ? SidebarMetrics.regularTop : 0,
                    bottom: regular ? SidebarMetrics.regularTop : 20,
                  ))
              .resolve(Directionality.of(context))
              .add(
                EdgeInsets.only(
                  top: media.padding.top,
                  bottom: media.padding.bottom,
                ),
              );
      final list = MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        child: ListView(
          controller: controller,
          primary: primary,
          physics: physics,
          padding: insets,
          children: [
            for (var i = 0; i < sections.length; i++)
              _SidebarSection<T>(
                key: ValueKey<int>(i),
                section: sections[i],
                first: i == 0,
                last: i == sections.length - 1,
                selection: selection,
                onSelect: onSelectionChanged == null
                    ? null
                    : (value) => _select(context, value),
                material: material,
                regular: regular,
                mode: mode,
              ),
          ],
        ),
      );
      if (material) {
        return Material(
          color:
              backgroundColor ??
              Theme.of(context).colorScheme.surfaceContainerLow,
          child: list,
        );
      }
      if (regular && backgroundColor == null) return list;
      return ColoredBox(
        color:
            backgroundColor ??
            CupertinoDynamicColor.resolve(
              GlassColors.sidebarListBackground,
              context,
            ),
        child: list,
      );
    },
  );
}

/// One section: its header, and the rows that spring open beneath it.
class _SidebarSection<T> extends StatefulWidget {
  const _SidebarSection({
    super.key,
    required this.section,
    required this.first,
    required this.last,
    required this.selection,
    required this.onSelect,
    required this.material,
    required this.regular,
    required this.mode,
  });

  final GlassSidebarSection<T> section;
  final bool first;
  final bool last;
  final T? selection;
  final ValueChanged<T>? onSelect;
  final bool material;
  final bool regular;
  final GlassRenderMode? mode;

  @override
  State<_SidebarSection<T>> createState() => _SidebarSectionState<T>();
}

class _SidebarSectionState<T> extends State<_SidebarSection<T>>
    with SingleTickerProviderStateMixin {
  late bool _internalExpanded;

  /// The expand/collapse progress: 0 collapsed, 1 expanded.
  late final AnimationController _controller;

  /// [_controller] clamped to 0..1 for the size and opacity transitions.
  late final Animation<double> _sizeFactor = _Clamped(_controller);

  /// Whether the rows are in the tree; they leave once fully collapsed.
  late bool _rowsMounted;

  bool get _collapsible =>
      widget.section.collapsible && widget.section.header != null;

  bool get _expanded =>
      !_collapsible || (widget.section.isExpanded ?? _internalExpanded);

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    _internalExpanded = widget.section.initiallyExpanded;
    _controller = AnimationController(vsync: this, value: _expanded ? 1 : 0);
    _rowsMounted = _controller.value > 0;
    _controller.addListener(_synced);
  }

  @override
  void didUpdateWidget(_SidebarSection<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.section;
    final was =
        !(old.collapsible && old.header != null) ||
        (old.isExpanded ?? _internalExpanded);
    if (_expanded != was) _animateTo(_expanded);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Lands the spring exactly on its end and drops the rows from the
  /// tree once fully collapsed.
  void _synced() {
    if (!_controller.isAnimating) {
      final end = _expanded ? 1.0 : 0.0;
      if (_controller.value != end) _controller.value = end;
    }
    if (_rowsMounted != _controller.value > 0) {
      setState(() => _rowsMounted = _controller.value > 0);
    }
  }

  void _toggle() {
    if (!_collapsible) return;
    final next = !_expanded;
    widget.section.onExpansionChanged?.call(next);
    if (widget.section.isExpanded == null) {
      setState(() => _internalExpanded = next);
      _animateTo(next);
    }
  }

  /// Springs the rows to [target] as SwiftUI's section does, or jumps
  /// under Reduce Motion.
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

  @override
  Widget build(BuildContext context) {
    final header = widget.section.header;
    final Widget rows = widget.material
        ? _materialRows(context)
        : widget.regular
        ? _regularRows(context)
        : _platter(context);
    final revealed = _rowsMounted
        ? SizeTransition(
            sizeFactor: _sizeFactor,
            alignment: AlignmentDirectional.topStart,
            child: FadeTransition(opacity: _sizeFactor, child: rows),
          )
        : const SizedBox(width: double.infinity);
    final double gapAbove = widget.first
        ? 0
        : widget.material
        ? 8
        : widget.regular
        ? SidebarMetrics.regularSectionGap
        : SidebarMetrics.sectionGap;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: gapAbove),
        if (header != null)
          widget.material
              ? _materialHeader(context, header)
              : _header(context, header),
        revealed,
      ],
    );
  }

  // --- header -------------------------------------------------------

  Animation<double> _turns(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Tween<double>(
      begin: 0,
      end: (rtl ? -1.0 : 1.0) * DisclosureMetrics.expandedTurns,
    ).animate(_controller);
  }

  Widget _header(BuildContext context, Widget header) {
    final regular = widget.regular;
    final color = CupertinoDynamicColor.resolve(
      GlassColors.secondaryLabel,
      context,
    );
    // SwiftUI draws the section's chevron in the label colour.
    final chevronColor = CupertinoDynamicColor.resolve(
      GlassColors.label,
      context,
    );
    final style = IOSText.style(
      regular ? SidebarMetrics.regularHeaderSize : SidebarMetrics.headerSize,
      weight: FontWeight.w600,
      color: color,
    );
    final start = regular
        ? SidebarMetrics.regularHeaderInset
        : ListMetrics.margin + SidebarMetrics.headerStart;
    final end = regular
        ? SidebarMetrics.regularHeaderInset
        : ListMetrics.margin + DisclosureMetrics.chevronEnd;
    final box = SizedBox(
      height: regular
          ? SidebarMetrics.regularHeaderHeight
          : SidebarMetrics.headerHeight,
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: start, end: end),
        child: Row(
          children: [
            Expanded(
              child: DefaultTextStyle.merge(
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: header,
              ),
            ),
            if (_collapsible)
              DisclosureChevron(color: chevronColor, turns: _turns(context)),
          ],
        ),
      ),
    );
    final Widget titled = Semantics(
      header: true,
      child: _collapsible
          ? MergeSemantics(
              child: Semantics(
                header: true,
                button: true,
                expanded: _expanded,
                onTap: _toggle,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTap: _toggle,
                  child: box,
                ),
              ),
            )
          : box,
    );
    return titled;
  }

  // --- compact rows (iPhone) ----------------------------------------

  Widget _platter(BuildContext context) {
    final items = widget.section.items;
    final selected = [for (final item in items) item.value == widget.selection];
    final separator = CupertinoDynamicColor.resolve(
      GlassColors.listSeparator,
      context,
    );
    final fill = CupertinoDynamicColor.resolve(
      GlassColors.listRowPressed,
      context,
    );
    final ink = CupertinoDynamicColor.resolve(GlassColors.label, context);
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      Widget row = Semantics(
        selected: selected[i],
        child: GlassListTile(
          title: item.title,
          leading: item.icon == null
              ? null
              : IconTheme.merge(
                  data: IconThemeData(
                    color: item.enabled
                        ? ink
                        : CupertinoDynamicColor.resolve(
                            GlassColors.tertiaryLabel,
                            context,
                          ),
                  ),
                  child: item.icon!,
                ),
          value: item.badge,
          enabled: item.enabled,
          onTap: widget.onSelect == null || !item.enabled
              ? null
              : () => widget.onSelect!(item.value),
          mode: widget.mode,
        ),
      );
      if (item.semanticLabel != null) {
        row = Semantics(
          label: item.semanticLabel,
          excludeSemantics: true,
          selected: selected[i],
          button: true,
          child: row,
        );
      }
      // A separator hides where it would touch the selection.
      final separated =
          i < items.length - 1 && !selected[i] && !selected[i + 1];
      rows.add(
        Stack(
          children: [
            if (selected[i]) Positioned.fill(child: ColoredBox(color: fill)),
            row,
            if (separated)
              PositionedDirectional(
                start: item.icon != null
                    ? ListMetrics.textStart
                    : ListMetrics.horizontalPadding,
                end: ListMetrics.separatorEnd,
                bottom: 0,
                height: ListMetrics.separatorThickness,
                child: ColoredBox(color: separator),
              ),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: ListMetrics.margin,
        end: ListMetrics.margin,
        top: widget.section.header != null ? SidebarMetrics.headerGap : 0,
      ),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(ListMetrics.cornerRadius),
          ),
          color: CupertinoDynamicColor.resolve(
            GlassColors.listSectionBackground,
            context,
          ),
        ),
        child: ClipRSuperellipse(
          borderRadius: BorderRadius.circular(ListMetrics.cornerRadius),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
      ),
    );
  }

  // --- regular rows (iPad sidebar column) ---------------------------

  Widget _regularRows(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [for (final item in widget.section.items) _regularRow(item)],
  );

  Widget _regularRow(GlassSidebarItem<T> item) => _RegularRow<T>(
    item: item,
    selection: widget.selection,
    onSelect: widget.onSelect,
  );

  // --- Material -----------------------------------------------------

  Widget _materialHeader(BuildContext context, Widget header) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant);
    final box = SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 28, end: 16),
        child: Row(
          children: [
            Expanded(
              child: DefaultTextStyle.merge(style: style, child: header),
            ),
            if (_collapsible)
              RotationTransition(
                turns: Tween<double>(begin: 0, end: 0.5).animate(_sizeFactor),
                child: Icon(Icons.expand_less, color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
    return Semantics(
      header: true,
      child: _collapsible
          ? MergeSemantics(
              child: Semantics(
                header: true,
                button: true,
                expanded: _expanded,
                onTap: _toggle,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTap: _toggle,
                  child: box,
                ),
              ),
            )
          : box,
    );
  }

  Widget _materialRows(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListTileTheme.merge(
        shape: const StadiumBorder(),
        selectedTileColor: scheme.secondaryContainer,
        selectedColor: scheme.onSecondaryContainer,
        iconColor: scheme.onSurfaceVariant,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in widget.section.items) _materialRow(item, scheme),
          ],
        ),
      ),
    );
  }

  Widget _materialRow(GlassSidebarItem<T> item, ColorScheme scheme) {
    final selected = item.value == widget.selection;
    final tile = ListTile(
      selected: selected,
      enabled: item.enabled,
      leading: item.icon,
      title: item.title,
      trailing: item.badge == null ? null : Text(item.badge!),
      onTap: widget.onSelect == null || !item.enabled
          ? null
          : () => widget.onSelect!(item.value),
    );
    if (item.semanticLabel == null) return tile;
    return Semantics(
      label: item.semanticLabel,
      selected: selected,
      button: true,
      excludeSemantics: true,
      child: tile,
    );
  }
}

/// A row on the iPad sidebar's glass: icon and label at the sidebar tab
/// bar's measured positions, the selection a rounded fill.
class _RegularRow<T> extends StatefulWidget {
  const _RegularRow({
    required this.item,
    required this.selection,
    required this.onSelect,
  });

  final GlassSidebarItem<T> item;
  final T? selection;
  final ValueChanged<T>? onSelect;

  @override
  State<_RegularRow<T>> createState() => _RegularRowState<T>();
}

class _RegularRowState<T> extends State<_RegularRow<T>> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final selected = item.value == widget.selection;
    final enabled = item.enabled && widget.onSelect != null;
    // SwiftUI tints the selected row's icon and title.
    final ink = !item.enabled
        ? CupertinoDynamicColor.resolve(GlassColors.tertiaryLabel, context)
        : selected
        ? CupertinoTheme.of(context).primaryColor
        : CupertinoDynamicColor.resolve(GlassColors.label, context);
    final fill = CupertinoDynamicColor.resolve(
      GlassColors.sidebarListSelection,
      context,
    );
    const iconCentre =
        TabSidebarMetrics.rowIconCentre - TabSidebarMetrics.rowInset;
    const iconSize = TabSidebarMetrics.rowIconSize;
    final style = IOSText.style(TabSidebarMetrics.labelSize, color: ink);
    final row = SizedBox(
      height: SidebarMetrics.regularRowHeight,
      child: DecoratedBox(
        decoration: selected || _pressed
            ? ShapeDecoration(shape: const StadiumBorder(), color: fill)
            : const BoxDecoration(),
        child: Stack(
          children: [
            if (item.icon != null)
              PositionedDirectional(
                start: iconCentre - iconSize,
                width: iconSize * 2,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconTheme.merge(
                    data: IconThemeData(color: ink, size: iconSize),
                    child: item.icon!,
                  ),
                ),
              ),
            PositionedDirectional(
              start: item.icon != null
                  ? TabSidebarMetrics.rowLabelStart - TabSidebarMetrics.rowInset
                  : SidebarMetrics.regularHeaderInset -
                        TabSidebarMetrics.rowInset,
              top: 0,
              bottom: 0,
              end: ListMetrics.horizontalPadding,
              child: Row(
                children: [
                  Expanded(
                    child: DefaultTextStyle.merge(
                      style: style,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: item.title,
                    ),
                  ),
                  if (item.badge != null)
                    Text(
                      item.badge!,
                      style: IOSText.style(
                        TabSidebarMetrics.labelSize,
                        color: CupertinoDynamicColor.resolve(
                          GlassColors.secondaryLabel,
                          context,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TabSidebarMetrics.rowInset,
      ),
      child: Semantics(
        button: true,
        selected: selected,
        enabled: item.enabled,
        label: item.semanticLabel,
        excludeSemantics: item.semanticLabel != null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => _setPressed(true) : null,
          onTapUp: enabled ? (_) => _setPressed(false) : null,
          onTapCancel: enabled ? () => _setPressed(false) : null,
          onTap: enabled ? () => widget.onSelect!(item.value) : null,
          child: row,
        ),
      ),
    );
  }
}

/// The parent's value clamped to 0..1, so no spring overshoot reaches
/// the size and opacity transitions.
class _Clamped extends ProxyAnimation {
  _Clamped(super.parent);

  @override
  double get value => super.value.clamp(0.0, 1.0);
}

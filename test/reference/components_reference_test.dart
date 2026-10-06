import 'dart:convert';
import 'dart:io';

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart'
    show GlassSheetDetent, GlassStepper;
import 'package:adaptive_liquid_glass/src/controls/control_metrics.dart';
import 'package:adaptive_liquid_glass/src/core/glass_colors.dart';
import 'package:adaptive_liquid_glass/src/date_picker/date_picker_metrics.dart';
import 'package:adaptive_liquid_glass/src/dialog/dialog_metrics.dart';
import 'package:adaptive_liquid_glass/src/menu/menu_metrics.dart';
import 'package:adaptive_liquid_glass/src/popover/popover_metrics.dart';
import 'package:adaptive_liquid_glass/src/scaffold/scaffold_metrics.dart';
import 'package:adaptive_liquid_glass/src/search/search_metrics.dart';
import 'package:adaptive_liquid_glass/src/sheet/sheet_metrics.dart';
import 'package:adaptive_liquid_glass/src/swipe/swipe_metrics.dart';
import 'package:adaptive_liquid_glass/src/toolbar/toolbar_metrics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every component constant against SwiftUI on iOS 26.4, as measured by
/// tool/reference/measure_components.py into controls.json.
void main() {
  final json =
      jsonDecode(File('tool/reference/controls.json').readAsStringSync())
          as Map<String, dynamic>;
  final c = json['components'] as Map<String, dynamic>;
  Map<String, dynamic> m(String key) => c[key] as Map<String, dynamic>;
  double n(Map<String, dynamic> map, String key) =>
      (map[key] as num).toDouble();
  Color hex(Map<String, dynamic> map, String key) => Color(
    0xFF000000 | int.parse((map[key] as String).substring(1), radix: 16),
  );
  // Measured on a 3x screenshot: a third of a point, plus antialiasing.
  const pt = 0.5;
  // One step of 255 either way per channel.
  Matcher sameColour(Color expected) => predicate<Color>(
    (got) =>
        ((got.r - expected.r).abs() * 255).round() <= 2 &&
        ((got.g - expected.g).abs() * 255).round() <= 2 &&
        ((got.b - expected.b).abs() * 255).round() <= 2,
    'within 2/255 of $expected',
  );

  test('toggle', () {
    final t = m('toggle');
    expect(
      ControlMetrics.toggleWidth,
      moreOrLessEquals(n(t, 'width'), epsilon: pt),
    );
    expect(
      ControlMetrics.toggleHeight,
      moreOrLessEquals(n(t, 'height'), epsilon: pt),
    );
    expect(
      ControlMetrics.toggleThumbWidth,
      moreOrLessEquals(n(t, 'thumb_width'), epsilon: pt),
    );
    expect(
      ControlMetrics.toggleHeight - ControlMetrics.thumbInset * 2,
      moreOrLessEquals(n(t, 'thumb_height'), epsilon: pt),
    );
    expect(
      ControlMetrics.thumbInset,
      moreOrLessEquals(n(t, 'thumb_inset'), epsilon: pt),
    );
    expect(CupertinoColors.systemGreen.color, sameColour(hex(t, 'on_colour')));
    expect(GlassColors.toggleOff.color, sameColour(hex(t, 'off_colour')));
    expect(
      GlassColors.toggleOff.darkColor,
      sameColour(hex(t, 'dark_off_colour')),
    );
  });

  test('slider', () {
    final s = m('slider');
    expect(
      ControlMetrics.sliderTrack,
      moreOrLessEquals(n(s, 'track_height'), epsilon: pt),
    );
    expect(
      ControlMetrics.sliderThumbWidth,
      moreOrLessEquals(n(s, 'thumb_width'), epsilon: pt),
    );
    expect(
      ControlMetrics.sliderThumbHeight,
      moreOrLessEquals(n(s, 'thumb_height'), epsilon: pt),
    );
    // The track runs the slider's full width (300 in the scene).
    expect(
      n(s, 'track_x1') - n(s, 'track_x0'),
      moreOrLessEquals(300, epsilon: pt),
    );
    expect(GlassColors.sliderFill.color, sameColour(hex(s, 'fill_colour')));
    expect(
      GlassColors.sliderFill.darkColor,
      sameColour(hex(s, 'dark_fill_colour')),
    );
    expect(GlassColors.sliderRest.color, sameColour(hex(s, 'rest_colour')));
    expect(
      GlassColors.sliderRest.darkColor,
      sameColour(hex(s, 'dark_rest_colour')),
    );
  });

  test('segmented control', () {
    final s = m('segmented');
    expect(
      ControlMetrics.segmentedHeight,
      moreOrLessEquals(n(s, 'height'), epsilon: pt),
    );
    expect(
      ControlMetrics.thumbInset,
      moreOrLessEquals(n(s, 'thumb_inset'), epsilon: pt),
    );
    // "Week": the k ascender, ~0.74 em of SF Pro.
    expect(
      ControlMetrics.segmentedFontSize * 0.74,
      moreOrLessEquals(n(s, 'week_ink'), epsilon: pt),
    );
    expect(GlassColors.segmentTrack.color, sameColour(hex(s, 'track_colour')));
    expect(
      GlassColors.segmentTrack.darkColor,
      sameColour(hex(s, 'dark_track_colour')),
    );
    expect(GlassColors.segmentThumb.color, sameColour(hex(s, 'thumb_colour')));
    expect(
      GlassColors.segmentThumb.darkColor,
      sameColour(hex(s, 'dark_thumb_colour')),
    );
  });

  test('toolbar', () {
    final t = m('toolbar');
    expect(
      ToolbarMetrics.height,
      moreOrLessEquals(n(t, 'height'), epsilon: pt),
    );
    expect(
      ToolbarMetrics.edgeInset,
      moreOrLessEquals(n(t, 'edge_inset'), epsilon: pt),
    );
    expect(
      ToolbarMetrics.edgeInset,
      moreOrLessEquals(n(t, 'edge_inset_trailing'), epsilon: pt),
    );
    expect(
      ToolbarMetrics.bottom,
      moreOrLessEquals(n(t, 'bottom_gap'), epsilon: pt),
    );
    final single = ToolbarMetrics.single;
    expect(
      single.iconOnlyHeight + single.iconOnlyExtraWidth,
      moreOrLessEquals(n(t, 'single_width'), epsilon: pt),
    );
    final grouped = ToolbarMetrics.grouped;
    expect(
      2 * (grouped.iconOnlyHeight + grouped.iconOnlyExtraWidth),
      moreOrLessEquals(n(t, 'pair_width'), epsilon: pt),
    );
  });

  test('bottom accessory and tab bar placement', () {
    final a = m('accessory');
    expect(
      ScaffoldMetrics.accessoryHeight,
      moreOrLessEquals(n(a, 'height'), epsilon: pt),
    );
    expect(
      ScaffoldMetrics.accessoryInset,
      moreOrLessEquals(n(a, 'inset'), epsilon: pt),
    );
    expect(
      ScaffoldMetrics.accessoryGap,
      moreOrLessEquals(n(a, 'gap'), epsilon: pt),
    );
    expect(
      ScaffoldMetrics.tabBarBottom,
      moreOrLessEquals(n(a, 'tab_bar_bottom_gap'), epsilon: pt),
    );
  });

  test('sheet', () {
    final s = m('sheet');
    expect(SheetMetrics.inset, moreOrLessEquals(n(s, 'inset'), epsilon: pt));
    expect(
      SheetMetrics.inset,
      moreOrLessEquals(n(s, 'bottom_gap'), epsilon: pt),
    );
    expect(
      SheetMetrics.grabberWidth,
      moreOrLessEquals(n(s, 'grabber_width'), epsilon: pt),
    );
    expect(
      SheetMetrics.grabberHeight,
      moreOrLessEquals(n(s, 'grabber_height'), epsilon: pt),
    );
    expect(
      SheetMetrics.grabberTop,
      moreOrLessEquals(n(s, 'grabber_top'), epsilon: pt),
    );
    expect(
      SheetMetrics.cornerRadius,
      moreOrLessEquals(n(s, 'corner_radius_circle'), epsilon: 1),
    );
    expect(
      GlassColors.sheetBarrier.a,
      moreOrLessEquals(n(s, 'barrier_alpha'), epsilon: 0.01),
    );
  });

  test('menu', () {
    final mm = m('menu');
    expect(MenuMetrics.width, moreOrLessEquals(n(mm, 'width'), epsilon: pt));
    expect(
      MenuMetrics.rowHeight,
      moreOrLessEquals(n(mm, 'row_pitch'), epsilon: pt),
    );
    expect(
      MenuMetrics.verticalPadding,
      moreOrLessEquals(n(mm, 'padding'), epsilon: pt),
    );
    expect(
      MenuMetrics.verticalPadding * 2 + MenuMetrics.rowHeight * 3,
      moreOrLessEquals(n(mm, 'height'), epsilon: 1),
    );
    expect(
      MenuMetrics.labelStart,
      moreOrLessEquals(n(mm, 'label_start'), epsilon: pt),
    );
    expect(
      MenuMetrics.iconCentre,
      moreOrLessEquals(n(mm, 'icon_centre'), epsilon: pt),
    );
    // "Share": the h ascender, ~0.74 em.
    expect(
      MenuMetrics.fontSize * 0.74,
      moreOrLessEquals(n(mm, 'label_ink'), epsilon: pt),
    );
    expect(
      MenuMetrics.cornerRadius,
      moreOrLessEquals(n(mm, 'corner_radius_circle'), epsilon: 1),
    );
  });

  test('search field', () {
    final s = m('search');
    expect(SearchMetrics.height, moreOrLessEquals(n(s, 'height'), epsilon: pt));
    expect(
      SearchMetrics.startInset,
      moreOrLessEquals(n(s, 'icon_start'), epsilon: pt),
    );
    expect(
      SearchMetrics.startInset + SearchMetrics.iconSize + SearchMetrics.iconGap,
      moreOrLessEquals(n(s, 'placeholder_start'), epsilon: pt),
    );
    // "Search": the h ascender, ~0.74 em, 17 pt.
    expect(
      SearchMetrics.fontSize * 0.74,
      moreOrLessEquals(n(s, 'placeholder_ink'), epsilon: pt),
    );
  });

  test('swipe actions', () {
    final s = m('swipe');
    final compact = s['compact'] as Map<String, dynamic>;
    final leading = s['compact_leading'] as Map<String, dynamic>;
    final stacked = s['stacked'] as Map<String, dynamic>;
    for (final key in ['gap_row', 'gap_between', 'gap_edge']) {
      expect(
        SwipeMetrics.gap,
        moreOrLessEquals(n(compact, key), epsilon: pt),
        reason: key,
      );
      expect(
        SwipeMetrics.gap,
        moreOrLessEquals(n(stacked, key), epsilon: pt),
        reason: key,
      );
    }
    expect(
      SwipeMetrics.gap,
      moreOrLessEquals(n(leading, 'gap_edge'), epsilon: pt),
    );
    expect(
      SwipeMetrics.gap,
      moreOrLessEquals(n(leading, 'gap_row'), epsilon: pt),
    );
    expect(
      n(compact, 'row_height') - SwipeMetrics.compactInset * 2,
      moreOrLessEquals(n(compact, 'capsule_height'), epsilon: pt),
    );
    expect(
      SwipeMetrics.compactInset,
      moreOrLessEquals(n(compact, 'capsule_inset_y'), epsilon: pt),
    );
    expect(
      SwipeMetrics.compactIconGap,
      moreOrLessEquals(n(compact, 'icon_label_gap'), epsilon: pt),
    );
    // Delete is the widest label: icon + gap + label + padding.
    expect(
      n(compact, 'delete_content') + SwipeMetrics.compactPadding * 2,
      moreOrLessEquals(n(compact, 'delete_width'), epsilon: 1),
    );
    expect(
      SwipeMetrics.compactPadding,
      moreOrLessEquals(n(leading, 'pin_padding'), epsilon: pt),
    );
    // Every action on a side is as wide as the widest.
    expect(
      n(compact, 'share_width'),
      moreOrLessEquals(n(compact, 'delete_width'), epsilon: 1),
    );
    // 13-pt labels ("Delete": the D cap and l ascender, ~0.72 em).
    expect(
      SwipeMetrics.label.fontSize! * 0.72,
      moreOrLessEquals(n(compact, 'label_ink'), epsilon: pt),
    );
    expect(
      SwipeMetrics.rowRadius,
      moreOrLessEquals(n(compact, 'platter_corner_radius_circle'), epsilon: 1),
    );
    expect(
      SwipeMetrics.rowRadius,
      moreOrLessEquals(n(stacked, 'platter_corner_radius_circle'), epsilon: 1),
    );
    expect(
      CupertinoColors.systemGrey5.color,
      sameColour(hex(compact, 'platter_colour')),
    );
    expect(
      SwipeMetrics.stackedWidth,
      moreOrLessEquals(n(stacked, 'capsule_width'), epsilon: pt),
    );
    expect(
      SwipeMetrics.stackedHeight,
      moreOrLessEquals(n(stacked, 'capsule_height'), epsilon: pt),
    );
    expect(
      SwipeMetrics.stackedInset,
      moreOrLessEquals(n(stacked, 'capsule_inset_y'), epsilon: pt),
    );
    expect(
      SwipeMetrics.stackedLabelGap,
      moreOrLessEquals(n(stacked, 'label_gap'), epsilon: pt),
    );
    expect(
      CupertinoColors.secondaryLabel.color.withValues(alpha: 1),
      isNotNull,
    );
    // The threshold lies between the two measured rows.
    expect(
      SwipeMetrics.stackedRowHeight,
      greaterThan(n(compact, 'row_height')),
    );
    expect(
      SwipeMetrics.stackedRowHeight,
      lessThanOrEqualTo(n(stacked, 'row_height')),
    );
  });

  test('large sheet', () {
    final s = m('sheet_large');
    expect(n(s, 'inset'), 0);
    expect(
      SheetMetrics.largeTopRadius,
      moreOrLessEquals(n(s, 'top_radius_circle'), epsilon: 1),
    );
    // The large sheet starts at the safe area's top (62 on iPhone 17 Pro).
    expect(
      GlassSheetDetent.large.resolve(const Size(402, 874), 62),
      moreOrLessEquals(874 - n(s, 'top'), epsilon: pt),
    );
  });

  test('alert and confirmation dialog', () {
    final a = m('alert');
    final d = m('dialog');
    expect(
      DialogMetrics.alertWidth,
      moreOrLessEquals(n(a, 'width'), epsilon: pt),
    );
    expect(
      DialogMetrics.dialogWidth,
      moreOrLessEquals(n(d, 'width'), epsilon: pt),
    );
    expect(
      DialogMetrics.cornerRadius,
      moreOrLessEquals(n(a, 'radius_circle'), epsilon: 1.5),
    );
    expect(
      DialogMetrics.cornerRadius,
      moreOrLessEquals(n(d, 'radius_circle'), epsilon: 1.5),
    );
    expect(
      DialogMetrics.buttonHeight,
      moreOrLessEquals(n(a, 'button_height'), epsilon: pt),
    );
    expect(
      DialogMetrics.padding,
      moreOrLessEquals(n(a, 'button_inset'), epsilon: pt),
    );
    expect(
      (DialogMetrics.alertWidth -
              DialogMetrics.padding * 2 -
              DialogMetrics.buttonSpacing) /
          2,
      moreOrLessEquals(n(a, 'button_width'), epsilon: pt),
    );
    // Centred in the safe area: (62 + 874 - 34) / 2.
    expect(n(a, 'centre_y'), moreOrLessEquals(451, epsilon: 1));
  });

  test('popover', () {
    final p = m('popover');
    expect(
      PopoverMetrics.margin,
      moreOrLessEquals(n(p, 'right_inset'), epsilon: pt),
    );
    // A one-line popover: 17-pt SF text (a 20.3-pt line), 16 padding, the
    // inset.
    expect(
      20.3 + 16 * 2 + PopoverMetrics.verticalInset * 2,
      moreOrLessEquals(n(p, 'height'), epsilon: 1),
    );
  });

  test('stepper and date picker', () {
    final s = m('stepper');
    expect(
      GlassStepper.size.width,
      moreOrLessEquals(n(s, 'width'), epsilon: pt),
    );
    expect(
      GlassStepper.size.height,
      moreOrLessEquals(n(s, 'height'), epsilon: pt),
    );
    expect(GlassColors.stepperFill.color, sameColour(hex(s, 'fill')));
    expect(GlassColors.stepperFill.darkColor, sameColour(hex(s, 'dark_fill')));
    final dp = m('date_picker');
    expect(
      DatePickerMetrics.height,
      moreOrLessEquals(n(dp, 'height'), epsilon: pt),
    );
    expect(GlassColors.stepperFill.color, sameColour(hex(dp, 'fill')));
  });

  test('search tab', () {
    expect(
      ScaffoldMetrics.accessoryInset,
      moreOrLessEquals(n(m('search_tab'), 'circle_right_inset'), epsilon: pt),
    );
  });
}

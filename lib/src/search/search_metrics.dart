import 'package:flutter/physics.dart';

import '../core/swiftui_spring.dart';

/// iOS 26's search field, measured from SwiftUI's bottom `.searchable`
/// field on iPhone 17 Pro / iOS 26.4 (`tool/reference/controls.json`,
/// "components" → "search"; tested against it). SwiftUI floats it 28 pt
/// from the screen's sides and bottom, like the toolbar.
abstract final class SearchMetrics {
  /// The field's height.
  static const double height = 48;

  /// The magnifying glass's inset from the start.
  static const double startInset = 20;

  /// The clear button's inset from the end.
  static const double endInset = 8;

  /// The magnifying glass's size.
  static const double iconSize = 20;

  /// The gap between the magnifying glass and the text.
  static const double iconGap = 7.33;

  /// The text size.
  static const double fontSize = 17;

  /// The clear button's glyph size.
  static const double clearSize = 18;

  /// The clear button's padding, widening its touch target.
  static const double clearPadding = 6;

  // Searchable presentation. Measured from SwiftUI's active `.searchable`
  // (`-controls searchactive`, "components" → "searchable") unless marked
  // estimated.

  /// The idle bottom field's inset from the screen's sides (measured, as
  /// the toolbar's).
  static const double idleInset = 28;

  /// The idle bottom field's gap above the screen's bottom edge
  /// (measured).
  static const double idleBottom = 28;

  /// The active field's inset from the content's sides (measured).
  static const double inset = 12;

  /// The active field's gap above the keyboard (measured).
  static const double verticalInset = 12;

  // Navigation-bar placement: SwiftUI's `.navigationBarDrawer` field while
  // active (`-controls searchdrawerquery`, `searchdrawerplain`, `…query`;
  // "components" → "search_drawer").

  /// The field's top below the safe area's (measured: 70 under a 62-pt
  /// safe area).
  static const double drawerTop = 8;

  /// The field's and the close button's height (measured: 44, smaller
  /// than the bottom field).
  static const double drawerHeight = 44;

  /// The field's, close button's and scope bar's inset from the screen's
  /// sides (measured).
  static const double drawerInset = 16;

  /// The magnifying glass's inset from the field's start (measured: its
  /// ink 14 in, 6 less than the bottom field's).
  static const double drawerStartInset = startInset - 6;

  /// The clear button's inset from the field's end (measured: its ink
  /// 16 from the end, 5 less than the bottom field's).
  static const double drawerEndInset = endInset - 5;

  /// The gap between the field and the close button (measured).
  static const double drawerCancelGap = 11;

  /// The gap between the field and the scope bar (measured).
  static const double drawerScopeGap = 10;

  /// The gap between the field, or the scope bar under it, and the
  /// content (measured: 8 under the field, 10 under the scope bar).
  static const double drawerContentGap = 8;

  /// See [drawerContentGap].
  static const double drawerScopeContentGap = 10;

  /// The gap between the active field and the close button (measured).
  static const double cancelGap = 12;

  /// The close button's diameter: a glass xmark circle (measured).
  static const double cancelSize = 48;

  /// The scope bar's height (measured: 32, GlassSegmentedControl's).
  static const double scopeBarHeight = 32;

  /// With the bottom field, the scope bar's top below the safe area's
  /// (measured: SwiftUI shows it at the top once a query is typed, `-controls
  /// searchscopesquery`).
  static const double scopeTop = 2;

  /// The scope bar's inset from the screen's sides (measured).
  static const double scopeInset = 16;

  /// How far the scope bar pushes the content down (measured: the list's
  /// first row moves from 97 to 141).
  static const double scopeContentShift = 44;

  /// A suggestion row's least height (measured: SwiftUI lists suggestions
  /// as plain rows 53.67 apart with their 1-pt separators, in place of the
  /// content).
  static const double suggestionRowHeight = 52.67;

  /// The close button's reveal, fitted to three recordings of SwiftUI's
  /// (iOS 26.4, `-controls search` tapped, 60 fps frame dumps;
  /// tool/fidelity/record_component_motion.sh): one spring drives it, the
  /// field narrowing to make room over this first fraction (while it
  /// rides up with the keyboard) and the button growing over the rest.
  /// Fitted jointly with [revealScale] and [activation], rms 1.95 pt.
  static const double revealSplit = 0.13;

  /// The close button's size as it starts to grow in (fitted: 0.32, the
  /// first frames show it ~16 of its 48 pt wide).
  static const double revealScale = 0.32;

  /// The close button's reveal spring (fitted: the button overshoots to
  /// ~50 pt and settles at 48 about 0.6 s after the field starts to
  /// narrow).
  static final SpringDescription activation = swiftUISpring(
    response: 0.53,
    dampingFraction: 0.69,
  );

  /// The close button's hide, fitted to three recordings of SwiftUI's
  /// (iOS 26.4, `-controls searchmotion`, the close button tapped; 60 fps
  /// frame dumps): the row jumps to the idle insets in one frame, the
  /// button keeping its room, then the field's end springs over the room
  /// on this spring, ~7 pt past its rest and back (rms 1.85 pt), while
  /// the button's glass merges into the field's and its glyph fades (see
  /// [hideFade]).
  static final SpringDescription hide = swiftUISpring(
    response: 0.26,
    dampingFraction: 0.56,
  );

  /// The fraction of the [hide] spring over which the close button's
  /// glyph fades out, its glass merging into the field's instead
  /// (measured: the glyph is half gone two frames in and gone by the
  /// fourth, as the field starts to move).
  static const double hideFade = 0.12;
}

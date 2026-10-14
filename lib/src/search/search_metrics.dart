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

  /// The active field's gap above the keyboard (measured); also its
  /// inset from the top in the navigation-bar placement (estimated).
  static const double verticalInset = 12;

  /// The gap between the active field and the close button (measured).
  static const double cancelGap = 12;

  /// The close button's diameter: a glass xmark circle (measured).
  static const double cancelSize = 48;

  /// The gap between the field and the scope bar in the navigation-bar
  /// placement (estimated).
  static const double scopeGap = 8;

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

  /// The close button's reveal, measured from a recording of SwiftUI's
  /// (iOS 26.4, `-controls search` tapped, 60 fps): the field narrows to
  /// make room while it rides up with the keyboard, then the button grows
  /// in place from 0.28 of its size, fading in, settling ~10 frames later.
  /// This fraction of [activation] narrows the field; the rest grows the
  /// button.
  static const double revealSplit = 0.5;

  /// The close button's size as it starts to grow in (measured: its glyph
  /// first shows 5 of 17.7 pt wide).
  static const double revealScale = 0.28;

  /// The close button's reveal / hide spring (estimated: the sheet's; the
  /// recording's 0.37 s from tap-out to settled fits it).
  static final SpringDescription activation = swiftUISpring(
    response: 0.4,
    dampingFraction: 0.86,
  );
}

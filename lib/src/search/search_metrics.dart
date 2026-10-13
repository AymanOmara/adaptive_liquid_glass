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

  /// The gap between the field and the scope bar (estimated).
  static const double scopeGap = 8;

  /// The scope bar's height (estimated; GlassSegmentedControl's).
  static const double scopeBarHeight = 32;

  /// A suggestion row's least height (estimated).
  static const double suggestionRowHeight = 44;

  /// The suggestions platter's corner radius (estimated: the list
  /// platter's).
  static const double suggestionsRadius = 26;

  /// The gap between the platter and the field (estimated).
  static const double suggestionsGap = 8;

  /// The Cancel button's reveal / hide spring (estimated: the sheet's).
  static final SpringDescription activation = swiftUISpring(
    response: 0.4,
    dampingFraction: 0.86,
  );
}

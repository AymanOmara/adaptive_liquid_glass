/// SwiftUI's `Form`, measured on iPhone 17 Pro / iOS 26.4
/// (`-listform form` in example/ios/Runner/ListFormScenes.swift).
abstract final class FormMetrics {
  /// The first section's distance from the safe area's top (the first
  /// platter sits 42.33 pt below it under an 'Account' header).
  static const double topInset = 14.33;

  /// The last section's distance from the form's bottom.
  static const double bottomInset = 20;

  /// The gap between two platters with no caption between them.
  static const double sectionGap = 35;

  /// The gap between a section's footer and the next section's header
  /// (platter to platter measures 76 pt across a footer and a header).
  static const double captionSectionGap = 24;

  /// The Material path's top inset.
  static const double materialTopInset = 16;

  /// The Material path's bottom inset.
  static const double materialBottomInset = 16;

  /// The Material path's gap between sections.
  static const double materialSectionGap = 24;
}

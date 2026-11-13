import 'package:flutter/painting.dart' show FontWeight;

/// SwiftUI's `GroupBox`, measured on iPhone 17 Pro / iOS 26.4
/// (`-listform groupbox` in example/ios/Runner/ListFormScenes.swift).
abstract final class GroupBoxMetrics {
  /// The platter's corner radius (iOS 26 keeps GroupBox's small radius,
  /// unlike the 26-pt list platter).
  static const double cornerRadius = 8;

  /// The inset around the label and content.
  static const double padding = 16;

  /// The gap between the label and text content (SwiftUI's adaptive
  /// stack spacing between two texts; the label-to-text-to-bottom box
  /// measures 102.67 pt for two lines).
  static const double labelGap = 4.67;

  /// The gap between the label and a nested [GlassGroupBox], which
  /// SwiftUI's adaptive spacing widens.
  static const double nestedLabelGap = 13;

  /// The gap between the label's icon and its title (the title starts
  /// 65 pt in, the icon 34 pt).
  static const double labelIconGap = 13;

  /// The label's text size.
  static const double labelSize = 17;

  /// The label's weight (SwiftUI's headline).
  static const FontWeight labelWeight = FontWeight.w600;

  /// The label icon's size.
  static const double labelIconSize = 20;

  /// The content's text size.
  static const double contentSize = 17;
}

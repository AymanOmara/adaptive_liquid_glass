/// iOS 26's alert and confirmation dialog, measured from SwiftUI's
/// `.alert` and `.confirmationDialog` on iPhone 17 Pro / iOS 26.4
/// (`tool/reference/controls.json`, "components" → "alert" and "dialog";
/// tested against it). The presentation spring is not measured yet.
abstract final class DialogMetrics {
  /// The alert's width.
  static const double alertWidth = 320;

  /// The confirmation dialog's width.
  static const double dialogWidth = 240;

  /// The card's corner radius (circular fit 34.5).
  static const double cornerRadius = 34;

  /// The card's padding around its buttons.
  static const double padding = 16;

  /// The extra inset of the alert's text inside [padding] (text starts 30
  /// pt from the card's edge).
  static const double textInset = 14;

  /// The space above the title.
  static const double titleTop = 24;

  /// The space between the title and the message.
  static const double messageGap = 8;

  /// The space between the text and the buttons.
  static const double buttonsGap = 16;

  /// A button's height.
  static const double buttonHeight = 48;

  /// The space between buttons.
  static const double buttonSpacing = 8;

  /// The title's size (semibold in an alert).
  static const double titleSize = 17;

  /// The message's size.
  static const double messageSize = 15;

  /// A button's label size.
  static const double buttonSize = 17;
}

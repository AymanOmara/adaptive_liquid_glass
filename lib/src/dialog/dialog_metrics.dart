/// iOS 26's alert and confirmation dialog, measured from SwiftUI's
/// `.alert` and `.confirmationDialog` on iPhone 17 Pro / iOS 26.4
/// (`tool/reference/controls.json`, "components" → "alert" and "dialog";
/// tested against it). The presentation spring is not measured yet.
///
/// The confirmation dialog with a message (`showGlassActionSheet`) was
/// measured from SwiftUI iOS 26.4
/// `.confirmationDialog(titleVisibility: .visible)` with a message on
/// iPhone 17 Pro: a 240 x 256 pt card centred at y 450, its text laid
/// out as the alert's (title ink 27.7 pt below the card top, text
/// 30 pt from the card's sides, message lines 22 pt apart), 48 pt
/// buttons 8 pt apart, 16 pt below the last; no dim behind it.
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

  /// The space between a message and the buttons: [buttonsGap] plus the
  /// line spacing UIKit leaves below a message's last line (measured: the
  /// first button starts 35 pt below the last line's cap top).
  static const double messageButtonsGap = 20;

  /// The blur radius of the card's shadow (sigma ~60 pt, measured on
  /// white around the action sheet's card).
  static const double shadowBlur = 100;

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

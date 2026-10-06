/// iOS 26's action sheet, as UIKit's `UIAlertController` (.actionSheet)
/// draws it on iPhone: a glass card floating at the bottom of the screen.
/// The values are ESTIMATED from iOS 26 (UIKit/HIG defaults), not
/// measured from SwiftUI yet.
abstract final class ActionSheetMetrics {
  /// The card's inset from the screen's sides and the bottom safe area.
  static const double margin = 8;

  /// The card's corner radius, as the dialog card's.
  static const double cornerRadius = 34;

  /// The card's padding around its buttons.
  static const double padding = 16;

  /// The space above the title.
  static const double titleTop = 20;

  /// The gap between the title and the message.
  static const double textGap = 4;

  /// The gap between the text and the buttons.
  static const double buttonsGap = 16;

  /// The extra space above the cancel button.
  static const double cancelGap = 8;

  /// The title's size.
  static const double titleSize = 13;

  /// The message's size.
  static const double messageSize = 13;

  /// The card's widest, for tablets and landscape.
  static const double maxWidth = 500;
}

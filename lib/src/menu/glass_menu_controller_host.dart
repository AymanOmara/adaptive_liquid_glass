import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/widgets.dart' show Offset;

import 'glass_menu_controller.dart';

/// Implemented by the package's menus; not for apps.
@internal
abstract interface class GlassMenuControllerHost {
  /// Whether the menu is open.
  bool get isOpen;

  /// Opens the menu.
  void open();

  /// Closes the menu.
  void close();

  /// Highlights the row under [globalPosition]; see
  /// [GlassMenuController.glideTo].
  bool glideTo(Offset globalPosition);

  /// Activates the highlighted row; see [GlassMenuController.endGlide].
  bool endGlide();

  /// Clears the highlight; see [GlassMenuController.cancelGlide].
  void cancelGlide();
}

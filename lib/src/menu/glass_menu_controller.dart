import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/widgets.dart' show Offset;

/// External control of a glass menu: open and close it from code, and
/// glide a finger across its rows, slide-to-select, as iOS's menus do
/// under a long-press.
///
/// ```dart
/// final controller = GlassMenuController();
///
/// GestureDetector(
///   onLongPressStart: (_) => controller.open(),
///   onLongPressMoveUpdate: (details) =>
///       controller.glideTo(details.globalPosition),
///   onLongPressEnd: (_) => controller.endGlide(),
///   onLongPressCancel: controller.cancelGlide,
///   child: const Text('Hold, then slide'),
/// )
/// ```
///
/// The menu it drives:
///
/// ```dart
/// GlassMenuButton(
///   controller: controller,
///   icon: CupertinoIcons.ellipsis,
///   semanticLabel: 'More',
///   items: [
///     GlassMenuItem(
///       label: 'Copy',
///       icon: CupertinoIcons.doc_on_doc,
///       onSelected: copy,
///     ),
///   ],
/// )
/// ```
///
/// One controller drives one mounted menu: the menu attaches when it
/// builds and detaches when it goes. Gliding is a no-op on the Material
/// path, where opening and closing still work.
class GlassMenuController {
  GlassMenuControllerHost? _host;

  /// Whether the attached menu is open; false when none is attached.
  bool get isOpen => _host?.isOpen ?? false;

  /// Opens the attached menu; a no-op when it is already open.
  void open() => _host?.open();

  /// Closes the attached menu; a no-op when it is already closed.
  void close() => _host?.close();

  /// Highlights the enabled row under [globalPosition], as a gliding
  /// finger crosses the menu, and clicks (a selection haptic) each time
  /// the highlight moves to another row. A disabled row, the menu's
  /// padding and the space outside it highlight nothing.
  ///
  /// Returns whether the point lies over the menu; while the menu is
  /// closed, a no-op returning false. Gliding does nothing on the
  /// Material path.
  bool glideTo(Offset globalPosition) =>
      _host?.glideTo(globalPosition) ?? false;

  /// Activates the highlighted row exactly as a tap on it: the menu
  /// closes, then the item runs. Returns true. With nothing highlighted
  /// it clears the glide, leaves the menu open, and returns false; false
  /// too on the Material path.
  bool endGlide() => _host?.endGlide() ?? false;

  /// Clears the highlight, activating nothing; the menu stays open.
  void cancelGlide() => _host?.cancelGlide();

  /// Called by the menu when it mounts; not for apps.
  @internal
  void attach(GlassMenuControllerHost host) => _host = host;

  /// Called by the menu when it unmounts; not for apps.
  @internal
  void detach(GlassMenuControllerHost host) {
    if (identical(_host, host)) _host = null;
  }
}

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

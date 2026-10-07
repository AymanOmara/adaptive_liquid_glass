import 'package:flutter/widgets.dart';

/// Returned by [showGlassFullScreenCover].
///
/// The handle keeps working after the cover has closed: [result] holds
/// the value it closed with, and [dismiss] is then a no-op.
class GlassFullScreenCoverHandle<T> {
  /// Creates a handle for the cover's [ModalRoute].
  GlassFullScreenCoverHandle(this._route) {
    _route.popped.whenComplete(() => _active = false);
  }

  final ModalRoute<T> _route;

  /// Whether [dismiss] has closed this cover already.
  bool _active = true;

  /// Completes with the value the cover is popped with.
  Future<T?> get result => _route.popped;

  /// Whether the cover is still showing.
  bool get isActive => _active && _route.isActive;

  /// Dismisses the cover (a no-op when already gone), completing
  /// [result] with [value].
  void dismiss([T? value]) {
    if (!isActive) return;
    _active = false;
    final navigator = _route.navigator;
    if (navigator == null) return;
    // A current route animates out with a pop; one buried under later
    // routes is removed in place.
    if (_route.isCurrent) {
      navigator.pop(value);
    } else {
      navigator.removeRoute(_route, value);
    }
  }
}

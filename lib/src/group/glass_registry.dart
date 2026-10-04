import 'package:flutter/foundation.dart';

import 'glass_entry.dart';

/// The members of one `GlassGroup`.
class GlassRegistry extends ChangeNotifier {
  /// Maximum shapes drawn in one shader pass.
  static const int maxShapes = 16;

  final List<GlassEntry> _entries = [];

  /// Called after an entry is added.
  void Function(GlassEntry entry)? onAdded;

  /// Called after an entry is removed.
  void Function(GlassEntry entry)? onRemoved;

  /// Registered entries in registration order.
  List<GlassEntry> get entries => List.unmodifiable(_entries);

  /// Adds [e]. Returns `false` (and reports a non-fatal error) when full;
  /// the caller then renders [e] in its own implicit group.
  bool register(GlassEntry e) {
    if (_entries.length >= maxShapes) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: FlutterError(
            'A GlassGroup can merge at most $maxShapes shapes. Extra shapes '
            'are drawn on their own and will not merge.',
          ),
          library: 'adaptive_liquid_glass',
        ),
      );
      return false;
    }
    _entries.add(e);
    onAdded?.call(e);
    notifyListeners();
    return true;
  }

  /// Removes [e] if present.
  void unregister(GlassEntry e) {
    if (_entries.remove(e)) {
      onRemoved?.call(e);
      notifyListeners();
    }
  }

  /// Asks the group to repaint (geometry or press state changed).
  void markNeedsPaint() => notifyListeners();
}

import 'package:flutter/foundation.dart';

import 'glass_entry.dart';

/// The members of one `GlassGroup`.
class GlassRegistry extends ChangeNotifier {
  /// Maximum shapes drawn in one shader pass.
  static const int maxShapes = 16;

  final List<GlassEntry> _entries = [];

  // Whether this group has already reported going over [maxShapes]: the
  // error is reported once per group, not per extra member or rebuild.
  bool _reportedOverflow = false;

  /// Called after an entry is added.
  void Function(GlassEntry entry)? onAdded;

  /// Called after an entry is removed.
  void Function(GlassEntry entry)? onRemoved;

  /// Registered entries in registration order.
  List<GlassEntry> get entries => List.unmodifiable(_entries);

  /// Adds [e]. Returns `false` when full ([maxShapes] entries, unless not
  /// [capped]); the caller then renders [e] in its own implicit group.
  /// The first refusal reports a non-fatal error; later ones in the same
  /// group are silent.
  bool register(GlassEntry e, {bool capped = true}) {
    if (capped && _entries.length >= maxShapes) {
      if (!_reportedOverflow) {
        _reportedOverflow = true;
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: FlutterError(
              'A GlassGroup can merge at most $maxShapes shapes. Extra shapes '
              'are drawn on their own and will not merge.\n'
              'To share one native view without merging (a row of chips, '
              'a list of buttons), wrap them in a GlassBatch instead of a '
              'GlassGroup, or set LiquidGlassThemeData.batchImplicitGroups. '
              'This error is reported once per group.',
            ),
            library: 'adaptive_liquid_glass',
          ),
        );
      }
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

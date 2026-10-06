import 'package:flutter/widgets.dart';

import 'glass_entry.dart';

/// One morph in flight: a glass id moving from one frame to another.
class MorphTrack {
  /// Starts tracking [entry], driven by [controller].
  MorphTrack(this.entry, this.controller);

  /// The glass being morphed.
  GlassEntry entry;

  /// Runs the morph from 0 to 1.
  final AnimationController controller;

  /// Where the morph starts.
  Rect from = Rect.zero;

  /// Set when the old view with this id unmounts later.
  Rect? fromOverride;

  /// Where the morph ends; null resolves from the live box each tick.
  Rect? to;

  /// Whether the glass has gone and only its ghost is morphing out.
  bool ghost = false;
}

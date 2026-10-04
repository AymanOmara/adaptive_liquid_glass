import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/glass_constants.dart';
import '../core/swiftui_spring.dart';
import 'glass_entry.dart';
import 'glass_registry.dart';

class _Track {
  _Track(this.entry, this.controller);
  GlassEntry entry;
  final AnimationController controller;
  Rect from = Rect.zero;
  Rect? fromOverride; // set when the old view with this id unmounts later
  Rect? to; // null → resolve from the live box each tick
  bool ghost = false;
}

/// Animates `glassId` appearances, removals and identity moves, like
/// SwiftUI's `glassEffectID` inside a `GlassEffectContainer`.
///
/// Morph rects are in the group's local coordinates (the coordinate space of
/// the group's backdrop render object).
class GlassMorphController {
  /// Creates the controller and installs registry hooks.
  GlassMorphController({
    required this.vsync,
    required this.registry,
    required this.groupBox,
    required this.motion,
  }) {
    registry
      ..onAdded = _onAdded
      ..onRemoved = _onRemoved;
  }

  /// Ticker source.
  final TickerProvider vsync;

  /// The group's registry.
  final GlassRegistry registry;

  /// The group's render box (coordinate space for morph rects); null while
  /// the group is inactive (being torn down or reparented).
  final RenderBox? Function() groupBox;

  /// Current motion constants.
  final GlassMotionConstants Function() motion;

  final Map<Object, _Track> _tracks = {};
  bool _settled = false;
  bool _disposed = false;

  /// Called after the group's first frame; later arrivals animate.
  void markSettled() => _settled = true;

  void _onAdded(GlassEntry e) {
    final id = e.glassId;
    if (id == null || !_settled || _disposed) return;
    final previous = _tracks[id];
    final from = previous != null && previous.ghost
        ? previous.entry.morphRect
        : null;
    if (previous != null) _finish(id, removeGhost: true);
    e.morphRect = from ?? Rect.zero; // hidden until laid out
    e.contentOpacity.value = 0;
    final track = _tracks[id] = _Track(e, _newController());
    // Start after layout, when the target rect exists.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!identical(_tracks[id], track)) return;
      track.from =
          track.fromOverride ?? from ?? _nearestDrawn(e) ?? _collapsedAt(e);
      _run(id, track);
    });
  }

  void _onRemoved(GlassEntry e) {
    final id = e.glassId;
    if (id == null || _disposed) return;
    final live = _tracks[id];
    // The entry's own animation ends with it.
    if (live != null && identical(live.entry, e)) {
      _tracks.remove(id);
      live.controller.dispose();
      e.morphRect = null;
      if (e.box != null) e.contentOpacity.value = 1;
    }
    final last = e.lastDrawnLocal;
    final group = groupBox();
    if (!_settled ||
        e.box != null ||
        last == null ||
        group == null ||
        !group.attached) {
      return;
    }
    if (live != null && !identical(live.entry, e)) {
      // Same id, new view: the new member mounts before the old one
      // unmounts, so its track already exists. Morph it from where the old
      // one was; no ghost.
      if (!live.ghost) {
        live.fromOverride = last;
        return;
      }
      _finish(id, removeGhost: true); // a stale ghost of an older view
    }
    final nearest = _nearestDrawn(e);
    final track = _tracks[id] = _Track(e, _newController())
      ..ghost = true
      ..from = last
      ..to = Rect.fromCenter(
        center: (nearest ?? last).center,
        width: 0,
        height: 0,
      );
    e.morphRect = last;
    // Re-add without hooks so the ghost keeps drawing.
    final hook = registry.onAdded;
    registry.onAdded = null;
    final added = registry.register(e);
    registry.onAdded = hook;
    if (!added) {
      _tracks.remove(id)?.controller.dispose();
      e.morphRect = null;
      return;
    }
    _run(id, track);
  }

  AnimationController _newController() =>
      AnimationController.unbounded(vsync: vsync);

  Rect? _liveRect(GlassEntry e) {
    final group = groupBox();
    final box = e.box;
    if (group == null ||
        !group.attached ||
        box == null ||
        !box.attached ||
        !box.hasSize) {
      return null;
    }
    return MatrixUtils.transformRect(
      box.getTransformTo(group),
      e.shape.resolveRect(box.size),
    );
  }

  Rect? _nearestDrawn(GlassEntry self) {
    final target = _liveRect(self) ?? self.lastDrawnLocal;
    Rect? best;
    var bestD = double.infinity;
    for (final o in registry.entries) {
      final r = o.lastDrawnLocal;
      if (identical(o, self) || r == null) continue;
      final d = target == null ? 0.0 : (r.center - target.center).distance;
      if (d < bestD) {
        bestD = d;
        best = r;
      }
    }
    return best;
  }

  Rect _collapsedAt(GlassEntry e) {
    final r = _liveRect(e) ?? Rect.zero;
    return Rect.fromCenter(center: r.center, width: 0, height: 0);
  }

  void _run(Object id, _Track track) {
    final m = motion();
    final c = track.controller;
    void tick() {
      final to = track.to ?? _liveRect(track.entry);
      if (to == null) return;
      final t = c.value;
      track.entry.morphRect = Rect.lerp(track.from, to, t);
      if (!track.ghost) {
        track.entry.contentOpacity.value = t.clamp(0.0, 1.0);
      }
      registry.markNeedsPaint();
    }

    c
      ..value = 0
      ..addListener(tick);
    tick(); // draw the start rect until the spring's first tick
    c
        .animateWith(
          SpringSimulation(
            swiftUISpring(
              response: m.morphResponse,
              dampingFraction: m.morphDamping,
            ),
            0,
            1,
            0,
          ),
        )
        .whenCompleteOrCancel(() {
          if (identical(_tracks[id], track)) {
            _finish(id, removeGhost: track.ghost);
          }
        });
  }

  void _finish(Object id, {required bool removeGhost}) {
    final track = _tracks.remove(id);
    if (track == null) return;
    track.controller.dispose();
    final e = track.entry;
    if (removeGhost && track.ghost) {
      e.morphRect = null;
      final hook = registry.onRemoved;
      registry.onRemoved = null;
      registry.unregister(e);
      registry.onRemoved = hook;
    } else {
      e.morphRect = null;
      e.contentOpacity.value = 1;
      registry.markNeedsPaint();
    }
  }

  /// Stops all animations and removes hooks.
  void dispose() {
    _disposed = true;
    for (final t in _tracks.values) {
      t.controller.dispose();
    }
    _tracks.clear();
    registry
      ..onAdded = null
      ..onRemoved = null;
  }
}

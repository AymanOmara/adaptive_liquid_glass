import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/glass_constants.dart';
import '../group/glass_registry.dart';
import '../platform/glass_platform.dart';
import '../shader/glass_backdrop.dart';
import '../shader/glass_backdrop_config.dart';
import 'glass_layer.dart';
import 'glass_layer_slot.dart';

/// The shared layer of the route [context] is in, or null when the group
/// must draw its own glass: the switch is off for [platform], the glass is
/// opted out, an ancestor [SnapshotWidget] is snapshotting it ([snapshot]),
/// or there is no route or overlay to paint after.
GlassLayer? sharedGlassLayerOf(
  BuildContext context,
  TargetPlatform platform, {
  GlassSnapshotWatch? snapshot,
}) {
  if (!GlassSharedLayer.enabledFor(platform)) return null;
  if (GlassLayerOptOut.of(context)) return null;
  if (snapshot != null && (snapshot..update(context)).snapshotting) {
    return null;
  }
  final route = ModalRoute.of(context);
  if (route == null || Overlay.maybeOf(context) == null) return null;
  return GlassLayer.of(route);
}

/// Follows the controllers of the ancestor [SnapshotWidget]s.
///
/// A snapshot (the Zoom page transition's, for one) paints the page into an
/// image and draws it scaled and faded through its painter, which the
/// shared layer cannot see: painted after the route, the glass would stay
/// put, unscaled, outside the snapshot. While any ancestor snapshots, the
/// group draws its own glass in place, inside the image. A page has
/// several (the Zoom transition wraps it once to enter and once to exit).
class GlassSnapshotWatch {
  /// Calls [onChange] when snapshotting starts or stops.
  GlassSnapshotWatch(this.onChange);

  /// Called when [snapshotting] changes.
  final VoidCallback onChange;

  List<SnapshotController> _controllers = const [];

  /// Whether an ancestor snapshot is on.
  bool get snapshotting => _controllers.any((c) => c.allowSnapshotting);

  /// Finds [context]'s ancestor [SnapshotWidget]s up to its [Overlay] (a
  /// snapshot above it holds the layer's slot too); [sharedGlassLayerOf]
  /// calls it, from `build`.
  void update(BuildContext context) {
    final found = <SnapshotController>[];
    context.visitAncestorElements((e) {
      final w = e.widget;
      if (w is SnapshotWidget) found.add(w.controller);
      return w is! Overlay;
    });
    if (listEquals(found, _controllers)) return;
    for (final c in _controllers) {
      c.removeListener(onChange);
    }
    for (final c in found) {
      c.addListener(onChange);
    }
    _controllers = found;
  }

  /// Stops listening.
  void dispose() {
    for (final c in _controllers) {
      c.removeListener(onChange);
    }
    _controllers = const [];
  }
}

/// Shows a [GlassLayerSlot] for [layer] above the group's route, through
/// an `OverlayPortal` (painted after the route's whole overlay entry and
/// before the next one). Without an overlay it is just [child].
class GlassLayerAnchor extends StatefulWidget {
  /// Creates an anchor.
  const GlassLayerAnchor({super.key, required this.layer, required this.child});

  /// The layer to show a slot for; null shows none.
  final GlassLayer? layer;

  /// The group.
  final Widget child;

  @override
  State<GlassLayerAnchor> createState() => _GlassLayerAnchorState();
}

class _GlassLayerAnchorState extends State<GlassLayerAnchor> {
  // Always showing: a portal cannot be shown or hidden while building, and
  // the layer comes and goes in build (a snapshot starting or stopping).
  // Without a layer the overlay child is an empty box.
  final OverlayPortalController _portal = OverlayPortalController()..show();

  @override
  Widget build(BuildContext context) {
    if (Overlay.maybeOf(context) == null) return widget.child;
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (_) {
        final layer = widget.layer;
        return layer == null
            ? const SizedBox.shrink()
            : IgnorePointer(child: GlassLayerSlot(layer: layer));
      },
      child: widget.child,
    );
  }
}

final GlassRegistry _noMembers = GlassRegistry();

const GlassBackdropConfig _noGlass = GlassBackdropConfig(
  spacing: 0,
  lightAngle: 0,
  devicePixelRatio: 1,
  constants: GlassConstants.standard,
  brightness: Brightness.light,
  highContrast: false,
);

/// Content painted over shader glass that is not inside the glass's group
/// (a sibling laid on top, like the tab bar's row over its bar).
///
/// On the shared layer a group's glass draws after the whole route, so such
/// content would end up beneath it; this defers [child] the same way a
/// group's own content is deferred, in paint order. Off the layer (or with
/// [enabled] false: the glass is not shader glass) it paints in place.
class GlassLayerContent extends StatefulWidget {
  /// Defers [child] when the glass it covers is on the shared layer.
  const GlassLayerContent({
    super.key,
    required this.enabled,
    required this.child,
  });

  /// Whether the glass beneath is shader glass.
  final bool enabled;

  /// The content.
  final Widget child;

  @override
  State<GlassLayerContent> createState() => _GlassLayerContentState();
}

class _GlassLayerContentState extends State<GlassLayerContent> {
  late final GlassSnapshotWatch _snapshot = GlassSnapshotWatch(() {
    if (mounted) setState(() {});
  });

  @override
  void dispose() {
    _snapshot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layer = widget.enabled
        ? sharedGlassLayerOf(
            context,
            GlassPlatform.instance.environment.value.platform,
            snapshot: _snapshot,
          )
        : null;
    return GlassLayerAnchor(
      layer: layer,
      child: GlassBackdrop(
        registry: _noMembers,
        config: _noGlass,
        sharedLayer: layer,
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}

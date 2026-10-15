import 'package:flutter/widgets.dart';

import 'glass_layer.dart';
import 'glass_layer_slot.dart';

/// The shared layer of the route [context] is in, or null when the group
/// must draw its own glass: the switch is off for [platform], the glass is
/// opted out, or there is no route or overlay to paint after.
GlassLayer? sharedGlassLayerOf(BuildContext context, TargetPlatform platform) {
  if (!GlassSharedLayer.enabledFor(platform)) return null;
  if (GlassLayerOptOut.of(context)) return null;
  final route = ModalRoute.of(context);
  if (route == null || Overlay.maybeOf(context) == null) return null;
  return GlassLayer.of(route);
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
  final OverlayPortalController _portal = OverlayPortalController();

  void _sync() {
    if (widget.layer != null && !_portal.isShowing) _portal.show();
    if (widget.layer == null && _portal.isShowing) _portal.hide();
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(GlassLayerAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

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

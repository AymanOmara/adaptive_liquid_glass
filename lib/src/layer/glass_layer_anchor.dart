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
/// See [GlassLayerDeferred].
class GlassLayerContent extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final layer = enabled
        ? sharedGlassLayerOf(
            context,
            GlassPlatform.instance.environment.value.platform,
          )
        : null;
    return GlassLayerAnchor(
      layer: layer,
      child: GlassBackdrop(
        registry: _noMembers,
        config: _noGlass,
        sharedLayer: layer,
        child: RepaintBoundary(
          child: GlassLayerDeferred(deferred: layer != null, child: child),
        ),
      ),
    );
  }
}

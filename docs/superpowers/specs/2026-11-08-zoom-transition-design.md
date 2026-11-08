# Zoom transition — design

TODO.md item 9. SwiftUI: `.matchedTransitionSource(id:in:)` on a source view,
`.navigationTransition(.zoom(sourceID:in:))` on the pushed destination.
Decided autonomously from existing patterns (`showGlassFullScreenCover`,
`GlassAdaptive`), per the session brief.

## API

- `GlassZoomSource({required Object id, Object? namespace, BorderRadiusGeometry borderRadius = BorderRadius.zero, required Widget child})`
  — marks the view a route zooms out of. The latest mounted source for
  `(namespace, id)` wins. Hidden while its route is pushed.
- `GlassZoomPageRoute<T>({required WidgetBuilder builder, required Object sourceId, Object? namespace, Color? backgroundColor, bool dragToDismiss = true, GlassRenderMode? mode, RouteSettings? settings})`
  — usable from `onGenerateRoute` (named routes).
- `Future<T?> pushGlassZoom<T>(BuildContext, {sourceId, builder, ...})` —
  convenience; mirrors `showGlassFullScreenCover`'s naming.

## Behaviour

- Push: the page (laid out full screen, opaque background) is drawn
  aspect-filled into a rounded rect that grows from the source's frame to the
  screen; the source's own pixels cross-fade out early; the source is hidden.
  Pop: the reverse, into the source's current frame.
- Interactive dismiss (glass path, `dragToDismiss`): a downward drag
  anywhere, or a horizontal drag from the leading edge (right in RTL),
  shrinks and moves the page with the finger; release past a distance or
  fling threshold pops (zooming back from the dragged frame), else it springs
  back. `PopScope` can refuse; inner vertical scrollables keep their drags;
  assistive tech gets a dismiss action.
- Missing source (unmounted / never registered): zoom from a centred,
  smaller frame with a fade.
- Reduce Motion: cross-fade, drag still dismisses (no spring).
- Material path (`GlassAdaptive.usesGlass` false): same container-transform
  geometry with Material 3 emphasized easing and durations; no drag (system
  back gesture).
- Timing: fitted from an iOS 26.4 SwiftUI recording (`-controls zoommotion`
  / `zoomdrag`), stored in `ZoomTransitionMetrics` with the fit error.

## Testing

Widget tests: source registration and lookup by namespace; flight rect at
t=0 equals source rect and at t=1 equals the screen; source hidden while
pushed and restored after pop; missing-source fallback; drag dismiss and
spring back; RTL leading edge; PopScope refusal; Reduce Motion fade; Material
path timing; `onGenerateRoute` usage. Reference test pins metrics to the
recorded fixture.

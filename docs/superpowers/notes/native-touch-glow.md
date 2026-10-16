# Native mode: SwiftUI's touch glow on pressed glass

**Outcome (2026-10-14):** SwiftUI's own glow cannot be triggered with
supported APIs (below).

**Update (2026-10-17):** native mode now draws the press light itself, as
it already drew the growth. `GlassPlatformView.swift` adds white with
`.plusLighter` inside each pressed shape: a lift over the whole shape plus
a Gaussian under the finger (`NativePressLight` in
`lib/src/native/native_glass_layer.dart`). Its timing is
`GlassPressController.light`: on in the frame of the touch, held 0.33 s
past the release while fading 20%, then off within a frame.

Measured with `MODE=native tool/fidelity/record_motion.sh … press-capsule-photo`
(iPhone 17 Pro, iOS 26.4): the SwiftUI frames minus this package's native
frames. The rest frames match exactly (it is the same Apple glass), so the
pressed residual is the light alone. Fitted inside the shape with the finger
fixed: light 10.2 + 5.0·G(σ 39 pt), dark 12.6 + 17.8·G(σ 43 pt), out of
255. SwiftUI realizes 89% (light) and 93% (dark) of a `.plusLighter` lift
inside glass, so the lifts are asked that much higher. In-shape |diff| over
the whole press went from 4.09 to 1.11 (light) and from 6.04 to 1.61 (dark).
At the hold, rms went from 12.6 to 4.2 and from 20.5 to 5.0, which is the
model's floor.

## Why

1. **UIKit never sees the touch mid-press.** Flutter wraps every iOS
   platform view in `FlutterTouchInterceptingView`, which carries a
   `FlutterDelayingGestureRecognizer` (engine,
   `shell/platform/darwin/ios/framework/Source/FlutterPlatformViews.mm`):
   - `delaysTouchesBegan = YES` and `delaysTouchesEnded = YES`, under both
     blocking policies (`Eager` and `WaitUntilTouchesEnded`), so
     `touchesBegan` reaches the embedded view only after Flutter decides;
   - its delegate returns YES from `shouldBeRequiredToFailByGestureRecognizer:`
     for every recognizer except Flutter's forwarding one, so no SwiftUI or
     UIKit recognizer inside the view can begin until the delaying recogniser
     fails.
   It fails only on `releaseGesture`, which the framework sends when the
   `UiKitView` **wins Flutter's gesture arena**. `WaitUntilTouchesEnded`
   changes only when a block takes effect, not the delay.

2. **Winning the arena would take the press away from the glass.** For the
   platform view to win at touch-down it needs an eager recogniser (e.g.
   `EagerGestureRecognizer` in `gestureRecognizers`), which rejects every
   other arena member: the member's tap / `onPressed`, scroll views, drags.
   Without it, the glass widget's own tap recogniser wins at touch-up (or the
   view is rejected at once, as now under `IgnorePointer`), so the view gets
   `blockGesture`, never `releaseGesture`, during the press. Either the glow
   is gated until after the press, or Flutter's hit-testing breaks.

3. **No public trigger for the glow.** SwiftUI's `Glass.interactive()` and
   UIKit's `UIGlassEffect.isInteractive` react only to real touches on the
   view. There is no API to set a highlighted/pressed state, and synthesising
   `UITouch` events needs private API (App Store rejection). Forwarding
   pointer events over the method channel therefore has nothing to drive.

4. **The real glow comes with SwiftUI's own press motion.** `.interactive()`
   also scales and bounces the glass. The package already grows and stretches
   the shapes from Dart (`glass_member.dart`, pushed through `setShapes`), and
   the Flutter content above follows that growth. Real touches reaching
   SwiftUI would grow the glass twice, and the glass would grow apart from
   its Flutter content.

## Not pursued: disabling Flutter's delaying recogniser

Setting `isEnabled = false` on the intercepting view's
`FlutterDelayingGestureRecognizer` from the plugin (found by class name in
`root.superview?.gestureRecognizers`), with UIKit interaction on for the
root and hosting views, would let SwiftUI see touches at once. It was
written but not measured: the simulator could not launch apps (the host
disk was full, 141 MB free). It is not recommended even if it works:
it relies on a private engine class name and structure, removes the gate
Flutter keeps for every platform view, and still has the double growth of
point 4 (the Dart-side press motion would have to be switched off in native
mode, losing content that grows with the glass).

## What would unlock it

- A public SwiftUI/UIKit API to set glass's interactive highlight (with a
  location) without touches; or
- a Flutter engine option to deliver touches to a platform view immediately
  while Flutter still owns the gesture (no such policy as of the Flutter in
  use here).

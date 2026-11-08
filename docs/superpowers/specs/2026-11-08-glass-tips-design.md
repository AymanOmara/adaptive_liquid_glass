# TipKit tips (`GlassTipView`, `GlassPopoverTip`) — design

TODO item 9, gap list "TipKit". API decided in-session (brief: don't block).

## API

- `GlassTip` — immutable content: `title` (Widget), `message`, `image`
  (Widgets, optional), `actions` (`List<GlassTipAction>`). Mirrors TipKit's
  `Tip` protocol; one value feeds both presentations.
- `GlassTipAction(label: String, onPressed)` — TipKit `Tip.Action`. Labels
  are app strings (locale-free package).
- `GlassTipController` (ChangeNotifier) — display rule "show until
  dismissed": `isDismissed`, `dismiss([reason])`, `reset()`,
  `onDismissed(GlassTipDismissReason)`. No storage: the app seeds
  `dismissed:` and persists in `onDismissed` (show once across launches).
  Reasons: `closed`, `actionPerformed` (TipKit `InvalidationReason`).
- `GlassTipView(tip:, controller:, mode:)` — inline tip; close button
  dismisses `closed`; collapses (size + fade; instant under Reduce Motion)
  and then builds nothing. No controller → local, non-persistent state.
- `GlassPopoverTip(tip:, controller:, child:, mode:)` — `.popoverTip`:
  wraps the anchor; while not dismissed it opens a tip bubble beside the
  anchor after the first frame (arrow pointing at it, below when there is
  room, otherwise above). Close button or tap outside → `closed`.
  Dismissing the controller elsewhere closes the open bubble.

## Look

Measured from native TipKit (iOS 26.4, iPhone 17 Pro; `-controls tips`,
`tipsdark`, `tippopover`) into `TipMetrics`. Glass paths: shader/native
glass platter (`LiquidGlass`, rect shape) with SF-style image leading,
headline title, secondary-label message, top-trailing xmark, actions under
a separator in tint colour. Material path (`GlassAdaptive` rule via
`GlassModeBuilder`): M3 card (surfaceContainerHigh), `IconButton` close,
`TextButton` actions; popover is the same card in a Material route.

## Rules

RTL via `EdgeInsetsDirectional`/`Row` order; light/dark via dynamic colours;
Reduce Motion: no scale/size animation, fade only; semantics: tip is a
container, close button labelled with Cupertino l10n-free "Close" passed as
`closeLabel` (default 'Close', overridable).

## Tests

Controller unit tests; inline layout (order, metrics, RTL mirror), close →
dismissed + callback, actions fire, controller hydrated dismissed builds
nothing, Material path card; popover opens after first frame beside anchor,
close/tap outside dismiss, external dismiss closes, dismissed never opens.

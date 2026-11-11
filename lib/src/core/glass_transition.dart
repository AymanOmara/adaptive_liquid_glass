/// How a `LiquidGlass` appears and disappears inside a `GlassGroup`, like
/// SwiftUI's `glassEffectTransition(_:)` with `GlassEffectTransition`.
enum GlassTransition {
  /// Morphs from and to the neighbouring glass (`.matchedGeometry`).
  ///
  /// The glass grows out of the nearest member when it appears and shrinks
  /// back into it when it goes, and a member whose `glassId` moves slides
  /// to its new place. Needs a `glassId`; without one the glass appears
  /// and disappears at once. This is the default.
  matchedGeometry,

  /// Appears and disappears in place (`.materialize`).
  ///
  /// The glass swells up from the middle of its own frame (and its content
  /// fades in with it) instead of travelling from a neighbour. Works with
  /// or without a `glassId`.
  materialize,

  /// No transition: the glass is simply there or not (`.identity`).
  ///
  /// A `glassId` still names the member for unions, but it no longer
  /// morphs.
  identity,
}

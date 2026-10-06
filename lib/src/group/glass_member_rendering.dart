/// How members of a group render themselves.
enum GlassMemberRendering {
  /// Registered with the group's shader backdrop.
  backdrop,

  /// Each member is a Material surface.
  material,

  /// Each member is a blur-only surface.
  degraded,

  /// Registered with the group's native (SwiftUI) glass layer, iOS 26+.
  native;

  /// Whether the group draws its members' glass (shader backdrop or native
  /// layer) rather than each member drawing its own surface.
  bool get drawnByGroup =>
      this == GlassMemberRendering.backdrop ||
      this == GlassMemberRendering.native;
}

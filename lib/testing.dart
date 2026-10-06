/// Fidelity-tuning hooks. Not part of the stable API.
///
/// Exports `GlassConstants`, the rendering constants fitted to SwiftUI
/// reference scenes. The fidelity harness builds them from JSON and passes
/// them through `LiquidGlassThemeData.constants`; apps do not need them.
library;

export 'src/core/glass_constants.dart';
export 'src/core/glass_motion_constants.dart';
export 'src/core/glass_variant_constants.dart';

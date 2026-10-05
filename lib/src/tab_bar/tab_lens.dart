import 'package:flutter/widgets.dart';

import '../core/glass_constants.dart';
import '../core/theme.dart';

/// The tab bar's lens, fitted to iOS 26.4's tab bar (Kept) frame by frame.
///
/// Unlike SwiftUI's clear glass (which pulls the inside towards its rim and
/// frosts), iOS's tab lens is unfrosted, refracts what lies just outside
/// its edge into a band about 6–8 pt wide (the page, the bar's edge), and
/// splits colour there. The lens is drawn with the package's shader and
/// these constants, even over native glass.
const tabLensLight = GlassVariantConstants(
  blurSigma: 0,
  lensBand: 1,
  lensStrength: 0,
  lensDecay: 1,
  lensSizeRef: 0,
  dispersion: 0.15,
  normalRadiusScale: 1,
  lensEdge: 0,
  lensEdgeDecay: 1.6,
  lensRingStart: 1,
  lensRingEnd: 7.5,
  lensRingReach: 4,
  rimMix: 0.3,
  rimMixWidth: 1.2,
  rimMixCut: 2,
  rimWidth: 1.2,
  rimIntensity: 0.65,
  fillColor: Color(0xFFFFFFFF),
  fillOpacity: 0.07,
  saturation: 1,
  dim: 0,
  shadowRadius: 0,
  shadowOpacity: 0,
  tintStrength: 0.35,
);

/// [tabLensLight] in dark mode.
const tabLensDark = GlassVariantConstants(
  blurSigma: 0,
  lensBand: 1,
  lensStrength: 0,
  lensDecay: 1,
  lensSizeRef: 0,
  dispersion: 0.15,
  normalRadiusScale: 1,
  lensEdge: 0,
  lensEdgeDecay: 1.6,
  lensRingStart: 1,
  lensRingEnd: 7.5,
  lensRingReach: 4,
  rimMix: 0.3,
  rimMixWidth: 1.2,
  rimMixCut: 2,
  rimMixLumaFloor: 0.05,
  rimWidth: 1.2,
  rimIntensity: 0.65,
  fillColor: Color(0xFFFFFFFF),
  fillOpacity: 0.06,
  saturation: 1,
  dim: 0,
  shadowRadius: 0,
  shadowOpacity: 0,
  tintStrength: 0.35,
);

/// [child] with clear glass drawn as the tab lens.
Widget withTabLens(BuildContext context, Widget child) {
  final theme = LiquidGlassTheme.of(context);
  return LiquidGlassTheme(
    data: theme.copyWith(
      constants: theme.constants.copyWith(
        clear: tabLensLight,
        clearDark: tabLensDark,
      ),
    ),
    child: child,
  );
}

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
  // A light blur after the bend: it scales with the compression, so the
  // squeezed band averages out (iOS shows faint ticks) and the rest stays
  // sharp.
  blurSigma: 0.75,
  postBlurShare: 0.9,
  // A near-linear outward bend over the outer 8.25 pt (33 pt at the rim,
  // about 5x compression: iOS squeezes the page above into the band)
  // plus an outward tail (negative lensEdge) that still moves the bar's
  // edge about 3.5 pt at 8 pt in.
  lensBand: 8.25,
  lensStrength: 4,
  lensDecay: 1000,
  lensSizeRef: 0,
  dispersion: -0.05,
  normalRadiusScale: 1,
  lensEdge: -6.7,
  lensEdgeDecay: 8,
  lensRingStart: 0,
  lensRingEnd: 0,
  lensRingReach: 0,
  rimMix: 0.55,
  rimMixWidth: 1.9,
  rimMixCut: 3,
  rimMixLumaFloor: 1,
  rimWidth: 1.2,
  rimIntensity: 0,
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
  // A light blur after the bend: it scales with the compression, so the
  // squeezed band averages out (iOS shows faint ticks) and the rest stays
  // sharp.
  blurSigma: 0.75,
  postBlurShare: 0.9,
  // A near-linear outward bend over the outer 8.25 pt (33 pt at the rim,
  // about 5x compression: iOS squeezes the page above into the band)
  // plus an outward tail (negative lensEdge) that still moves the bar's
  // edge about 3.5 pt at 8 pt in.
  lensBand: 8.25,
  lensStrength: 4,
  lensDecay: 1000,
  lensSizeRef: 0,
  dispersion: -0.05,
  normalRadiusScale: 1,
  lensEdge: -6.7,
  lensEdgeDecay: 8,
  lensRingStart: 0,
  lensRingEnd: 0,
  lensRingReach: 0,
  rimMix: 0.55,
  rimMixWidth: 1.9,
  rimMixCut: 3,
  rimMixLumaFloor: 1,
  rimWidth: 1.2,
  rimIntensity: 0,
  fillColor: Color(0xFFFFFFFF),
  // Kept over black: the bar's 25 reads 53 under the lens and black stays
  // near black (a gain, not a wash); the tinted tabs above keep their
  // colour (TabLensContent).
  toneKnots: [0.031, 0.257, 0.40, 0.52, 0.63, 0.73, 0.82, 0.91, 1.0],
  fillOpacity: 0,
  saturation: 1,
  dim: 0,
  shadowRadius: 0,
  shadowOpacity: 0,
  tintStrength: 0.35,
);

/// Colour split of the tinted tabs under the lens (TabLensContent); the
/// glass splits the backdrop less.
const tabLensContentDispersion = 0.15;

/// The tinted tabs' lens (TabLensContent): unlike the glass, which pushes
/// the backdrop outward all round, iOS pulls the tabs inward towards the
/// lens's round ends: band and decay (logical px) and strength, as
/// [GlassVariantConstants.lensBand] / [GlassVariantConstants.lensDecay] /
/// [GlassVariantConstants.lensStrength].
const tabLensContentBand = 20.0;

/// See [tabLensContentBand].
const tabLensContentDecay = 6.0;

/// See [tabLensContentBand].
const tabLensContentStrength = -0.8;

/// Blur radius of the tinted tabs at the lens's rim (logical px), easing
/// to none inside: iOS's bent tabs are soft.
const tabLensContentBlur = 2.5;

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

/// Overrides on regular glass for the tab bar itself, fitted to iOS 26.4's
/// tab bar (Kept) over black: UIKit's bar is flatter than SwiftUI's small
/// glass (no dark-end lift) with an even 1 pt rim.
const _tabBarOverrides = <String, Object?>{
  'toneLift': 0.0,
  'rimIntensity': 0.0,
  'rimMix': 0.144,
  'rimMixWidth': 1.33,
  'rimMixCut': 1.0,
  'rimMixLumaFloor': 1.0,
};

/// Dark-mode extras on [_tabBarOverrides]: the bar reads #191919 over black.
const _tabBarDarkOverrides = <String, Object?>{
  ..._tabBarOverrides,
  'fillColor': '#2B2A2B',
};

/// [child] with regular glass drawn as the tab bar.
Widget withTabBarGlass(BuildContext context, Widget child) {
  final theme = LiquidGlassTheme.of(context);
  final c = theme.constants;
  return LiquidGlassTheme(
    data: theme.copyWith(
      constants: c.copyWith(
        regular: GlassVariantConstants.fromJson(_tabBarOverrides, c.regular),
        regularDark: GlassVariantConstants.fromJson(
          _tabBarDarkOverrides,
          c.regularDark,
        ),
      ),
    ),
    child: child,
  );
}

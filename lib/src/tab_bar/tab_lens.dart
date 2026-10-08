import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../core/glass_colors.dart';
import '../core/glass_variant_constants.dart';
import '../core/liquid_glass_theme.dart';

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
  // A near-linear outward bend over the outer 8.25 pt (4 pt at the rim;
  // with the tail below the band reaches about 10 pt past the rim, as
  // iOS's does: about 8 pt, measured on `-controls lensreach`, a hue ramp
  // above the bar. 33 pt pulled whole text rows into the band.)
  // plus an outward tail (negative lensEdge) that still moves the bar's
  // edge about 3.5 pt at 8 pt in.
  lensBand: 8.25,
  lensStrength: 0.5,
  lensDecay: 1000,
  lensSizeRef: 0,
  dispersion: 0.3,
  normalRadiusScale: 1,
  lensEdge: -6.7,
  lensEdgeDecay: 8,
  // The bend is strongest where the lens faces up or down; its round
  // ends bend half as much (Kept: clear mid-bar, a rainbow crescent past
  // the bar's end).
  lensVertical: 0.5,
  // Kept's rim: teal-cyan (hue ~180), about 0.2 saturated.
  rimTint: 0.2,
  rimHue: 180,
  rimMix: 0.85,
  rimMixWidth: 1.4,
  rimMixCut: 3,
  rimMixLumaFloor: 1,
  rimWidth: 1.2,
  rimIntensity: 0,
  fillColor: GlassColors.white,
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
  // A near-linear outward bend over the outer 8.25 pt (4 pt at the rim;
  // with the tail below the band reaches about 10 pt past the rim, as
  // iOS's does: about 8 pt, measured on `-controls lensreach`, a hue ramp
  // above the bar. 33 pt pulled whole text rows into the band.)
  // plus an outward tail (negative lensEdge) that still moves the bar's
  // edge about 3.5 pt at 8 pt in.
  lensBand: 8.25,
  lensStrength: 0.5,
  lensDecay: 1000,
  lensSizeRef: 0,
  dispersion: 0.3,
  normalRadiusScale: 1,
  lensEdge: -6.7,
  lensEdgeDecay: 8,
  // The bend is strongest where the lens faces up or down; its round
  // ends bend half as much (Kept: clear mid-bar, a rainbow crescent past
  // the bar's end).
  lensVertical: 0.5,
  // Kept's rim: teal-cyan (hue ~180), about 0.2 saturated.
  rimTint: 0.2,
  rimHue: 180,
  rimMix: 0.85,
  rimMixWidth: 1.4,
  rimMixCut: 3,
  rimMixLumaFloor: 1,
  rimWidth: 1.2,
  rimIntensity: 0,
  fillColor: GlassColors.white,
  // Kept over black: the lit bar (about 48 by the lens) reads 53 under the
  // lens and black stays near black (a gain, not a wash); the tinted tabs
  // above keep their colour (TabLensContent).
  toneKnots: [0.031, 0.135, 0.255, 0.38, 0.5, 0.625, 0.75, 0.875, 1.0],
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

/// [child] with clear glass drawn as the tab lens. [bend] (0-1) scales its
/// refraction: iOS's lens bends in as it grows out of the pill, so a
/// pill-sized lens (still inside the bar) does not pull the page past the
/// bar's edge into a dark ring, nor light a rim yet (SwiftUI `TabView`,
/// iOS 26.4: the lens reads as even as the pill for its first frames).
Widget withTabLens(BuildContext context, Widget child, {double bend = 1}) {
  final theme = LiquidGlassTheme.of(context);
  return LiquidGlassTheme(
    data: theme.copyWith(
      constants: theme.constants.copyWith(
        clear: _bent(tabLensLight, bend),
        clearDark: _bent(tabLensDark, bend),
      ),
    ),
    child: child,
  );
}

GlassVariantConstants _bent(GlassVariantConstants c, double bend) => bend >= 1
    ? c
    : GlassVariantConstants.fromJson({
        'lensStrength': c.lensStrength * bend,
        'lensEdge': c.lensEdge * bend,
        'dispersion': c.dispersion * bend,
        'rimMix': c.rimMix * bend,
      }, c);

/// Overrides on regular glass for the tab bar itself, fitted to iOS 26.4's
/// tab bar (Kept, and SwiftUI's `TabView`): UIKit's bar is flatter than
/// SwiftUI's small glass (no dark-end lift) with an even 1 pt rim.
const _tabBarOverrides = <String, Object?>{
  // The shader's shadow is centred on the glass; iOS's tab bar shadow
  // sits lower, so the bar paints its own (BarShadow) instead.
  'shadowOpacity': 0.0,
  'rimIntensity': 0.0,
  'rimMix': 0.144,
  'rimMixWidth': 1.33,
  'rimMixCut': 1.0,
  'rimMixLumaFloor': 1.0,
  // The bar keeps the tone response it was fitted with: the g13 refit's
  // tone LUTs (and its small-shape curve, which a 62-pt bar falls under)
  // were fitted to SwiftUI's small glass and grey the bar (white page
  // 243 vs UIKit's 252; bar-region mean |diff| 1.35 -> 4.32).
  'toneKnots': GlassVariantConstants.identityToneKnots,
  'smallToneKnots': GlassVariantConstants.identityToneKnots,
};

/// Light-mode extras on [_tabBarOverrides], fitted to SwiftUI's `TabView`
/// (iOS 26.4) over `photo.png`: less white fill, less saturated and more
/// frosted than SwiftUI's small glass (the page's stripes fade to faint
/// strokes).
const _tabBarLightOverrides = <String, Object?>{
  ..._tabBarOverrides,
  'toneLift': 0.0,
  'fillOpacity': 0.62,
  'saturation': 1.45,
  'blurSigma': 7.0,
  // The values the bar was fitted with (before the g13 refit).
  'fillSizeDrop': 0.1268,
  'tintStrength': 1.0219,
};

/// Dark-mode extras on [_tabBarOverrides], fitted to SwiftUI's `TabView`
/// (iOS 26.4): the bar reads #131313 over black, and over `photo.png` it
/// lets more of the page through, less saturated and more frosted, than
/// SwiftUI's small glass.
const _tabBarDarkOverrides = <String, Object?>{
  ..._tabBarOverrides,
  'toneLift': 0.0,
  'fillColor': '#282828',
  'fillOpacity': 0.55,
  'saturation': 1.5,
  'blurSigma': 14.0,
  // The values the bar was fitted with (before the g13 refit).
  'fillSizeDrop': 0.798,
  'tintStrength': 1.0084,
};

/// The bar's dark glass while a lens is held is more see-through
/// (GlassColors.tabBarPressedFill at this opacity).
const _barPressedFillOpacity = 0.35;

/// [child] with regular glass drawn as the tab bar. [light] blends the dark
/// bar from rest (0) to its held look (1, kept while dragged).
Widget withTabBarGlass(BuildContext context, Widget child, {double light = 0}) {
  final theme = LiquidGlassTheme.of(context);
  final c = theme.constants;
  final p = light.clamp(0.0, 1.0);
  final rest = GlassVariantConstants.fromJson(
    _tabBarDarkOverrides,
    c.regularDark,
  );
  final dark = p == 0
      ? rest
      : GlassVariantConstants.fromJson({
          ..._tabBarDarkOverrides,
          'fillColor': _hex(
            Color.lerp(rest.fillColor, GlassColors.tabBarPressedFill, p)!,
          ),
          'fillOpacity': lerpDouble(
            rest.fillOpacity,
            _barPressedFillOpacity,
            p,
          ),
          'toneKnots': [
            for (var i = 0; i < 9; i++)
              lerpDouble(rest.toneKnots[i], tabLensDark.toneKnots[i], p),
          ],
        }, c.regularDark);
  return LiquidGlassTheme(
    data: theme.copyWith(
      constants: c.copyWith(
        regular: GlassVariantConstants.fromJson(
          _tabBarLightOverrides,
          c.regular,
        ),
        regularDark: dark,
      ),
    ),
    child: child,
  );
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

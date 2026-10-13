import 'package:flutter/cupertino.dart';

import '../core/swiftui_spring.dart';
import '../group/glass_content_fill.dart';

/// Measured from iOS 26.4's tab bar (Kept, iPhone 17 Pro) by frame-by-frame
/// tracking of press, hold, drag and release (`example/lib/tab_bar_probe.dart`
/// lays the bar out the same way).
abstract final class TabBarMetrics {
  /// The selected pill's system fill on native glass (GlassContentFill),
  /// light and dark, and its opacity.
  static const GlassFillStyle nativePillStyle = GlassFillStyle.quaternary;

  /// See [nativePillStyle].
  static const GlassFillStyle nativePillStyleDark = GlassFillStyle.secondary;

  /// See [nativePillStyle].
  static const double nativePillOpacity = 0.9;

  /// See [nativePillStyle].
  static const double nativePillOpacityDark = 0.97;

  /// The gap between the bar's edge and its tabs.
  static const double inset = 4;

  /// How much wider than the tab spacing the pill is: 93.98 over 86.0
  /// (measured from SwiftUI `TabView`, iOS 26.4: the pill's edges and the
  /// tabs' ink centres, to a third of a point).
  static const double pillExtra = 7.98;

  /// [pillExtra] when the bar fills the width beside a search tab or under
  /// an accessory (measured from SwiftUI `TabView`, iOS 26.4,
  /// `-controls searchtab` and `accessory`: pill 100.7 over 90.5 and 124.0
  /// over 114.0).
  static const double pillExtraFilled = 10.1;

  /// A badge's top leading corner from its tab icon's centre, towards the
  /// end and up (measured from SwiftUI `TabView` `.badge(3)`, iOS 26.4).
  static const Offset badgeOffset = Offset(12.2, -18.1);

  /// An empty badge's diameter: iOS draws `.badge("")` as an 18-pt circle,
  /// top-aligned with the count badges (measured, iOS 26.4).
  static const double emptyBadge = 18;

  /// The held lens over the pill: 112.3 by 76 against 93.7 by 54 (SwiftUI
  /// `TabView`, iOS 26.4, outline at frame 30 of a press; 20.6 stood
  /// 2.7 pt wider).
  static const double lensGrowX = 17.9;

  /// See [lensGrowX]. 22.6 rather than Kept's 20: SwiftUI's `TabView`
  /// (iOS 26.4) holds its lens 6.0 pt over the grown bar, ours stood 4.7
  /// at 20 (`tool/fidelity/tabbar_motion.py`, press).
  static const double lensGrowY = 22.6;

  /// A dragged lens stands lower than a held one: SwiftUI's `TabView`
  /// (iOS 26.4) holds it 6.0 pt over the grown bar and drags it at 4.0, so
  /// the drag takes this much off [lensGrowY] (blended in with the bar's
  /// dragged light).
  static const double lensDragDropY = 2.6;

  /// A lens springing one tab across is this much narrower than a held
  /// one, a longer hop more (x hop^0.6: SwiftUI's `TabView`, iOS 26.4,
  /// travels a press's one-tab hop about 11 pt narrower and a tap's
  /// two-tab hop about 17; a dragged lens is not; tabbar_motion.py).
  static const double lensTravelNarrow = 11;

  /// The lens sits 1.06 times as far from the bar's centre as the finger,
  /// up to this far past the outermost tab.
  static const double lensGain = 1.06;

  /// See [lensGain].
  static const double lensReach = 7.1;

  /// While held the bar grows this much on each side, plus [growLean] of
  /// the lens's offset from the centre towards the lens (SwiftUI `TabView`,
  /// iOS 26.4, `tool/fidelity/tabbar_motion.py`: 7.0 held, peaking at 7.7;
  /// Kept's wider bar grew 9.15).
  static const double growX = 7.0;

  /// See [growX] (1.7 on SwiftUI's `TabView`).
  static const double growY = 1.65;

  /// See [growX]. SwiftUI's `TabView` (iOS 26.4) shifts both bar edges
  /// about 1.15 pt as the dragged lens crosses 172 pt (Kept leaned 0.0237).
  static const double growLean = 0.0067;

  /// Tabs under the lens are magnified about their own centres (Kept).
  static const double magnifyX = 1.21;

  /// See [magnifyX].
  static const double magnifyY = 1.19;

  /// The tabs' magnification under the lens rising from a touch-down,
  /// whatever the lens's size does: SwiftUI's `TabView` (iOS 26.4) holds
  /// 1.22 through a press's settle and relift, while a quick tap's
  /// travelling lens magnifies 1.02-1.09 early and 1.14 on arrival.
  static final SpringDescription magnify = swiftUISpring(
    response: 0.35,
    dampingFraction: 1,
  );

  /// Where [magnify] heads after a quick tap's touch-up (a share of
  /// [magnifyX]/[magnifyY]'s extra): iOS's tapped lens reaches about 1.14.
  static const double tapMagnify = 0.65;

  /// Peak white of the light a held lens casts on the bar (see BarGlow).
  static const double glow = 0.095;

  /// How much of [glow] a drag takes away (SwiftUI's `TabView`, iOS 26.4:
  /// the bar keeps a softer glow around a dragged lens).
  static const double dragGlowDrop = 0.5;

  /// The bar's light coming on (press, drag) and fading after release
  /// (Kept: about a third left 16 frames after letting go; 0.18 on, as
  /// SwiftUI's `TabView` lights the far bar within ~4 frames of a press,
  /// tabbar_light.py).
  static final SpringDescription light = swiftUISpring(
    response: 0.18,
    dampingFraction: 1,
  );

  /// A drag keeps the held light this long, then softens it with
  /// [dragLight]: SwiftUI's `TabView` (iOS 26.4, over black) holds the
  /// lens's fill at 52 for ~20 frames of a drag, then eases it to 41 by
  /// frame ~36 (tabbar_fill.py).
  static const Duration dragLightDelay = Duration(milliseconds: 300);

  /// See [dragLightDelay].
  static final SpringDescription dragLight = swiftUISpring(
    response: 0.3,
    dampingFraction: 1,
  );

  /// See [light].
  static final SpringDescription lightOff = swiftUISpring(
    response: 0.45,
    dampingFraction: 1,
  );

  /// Native mode, dark: black tint on the lens's clear glass while the
  /// bar's light is off (scaled by 1 - light). UIKit's clear glass veils
  /// black at about 40 grey levels; iOS's tab lens, once the finger lifts,
  /// shows the bar and page through it.
  static const double nativeLensShade = 0.5;

  /// Shade on the native lens (dark) while dragged: SwiftUI's `TabView`
  /// (iOS 26.4) dims its dragged lens with the bar's softer light; at
  /// matched lens positions ours read +6.5 grey levels without it (+0.8
  /// with). A held lens keeps none (it read 3 levels darker with it).
  static const double nativeLensDragShade = 0.2;

  /// Black tint on the native lens in light mode: UIKit's clear glass over
  /// the white bar reads 255, SwiftUI's `TabView` lens 247 (iOS 26.4).
  static const double nativeLensLightShade = 0.035;

  /// The shadow under the native lens in light mode (UIKit's clear glass
  /// casts none; SwiftUI's `TabView` lens reads ~221 just below it).
  static const double nativeLensShadowOpacity = 0.1;

  /// See [nativeLensShadowOpacity].
  static const Offset nativeLensShadowOffset = Offset(0, 6);

  /// See [nativeLensShadowOpacity].
  static const double nativeLensShadowSigma = 5;

  /// The band at the lens's edge where content is refracted, not sharp.
  static const double lensRim = 9;

  /// The lens's height wobbles with its sideways acceleration (taller when
  /// it accelerates to the left), as a damped oscillator: points of extra
  /// overhang per side per pt/s² of acceleration.
  static const double wobbleGain = 0.002607;

  /// The wobble's oscillator; see [wobbleGain].
  static final SpringDescription wobble = swiftUISpring(
    response: 1.159,
    dampingFraction: 0.499,
  );

  /// A tab's icon size: CupertinoIcons drawn at 28 cover the ink of
  /// SwiftUI's tab symbols (gear 24 pt, house 27 pt wide; measured from
  /// SwiftUI `TabView`, iOS 26.4).
  static const double iconSize = 28;

  /// [GlassTabBarItem.symbol]'s SF Symbol configuration, as SwiftUI's
  /// `TabView` draws its tab symbols (iOS 26.4, fitted to its ink).
  static const double symbolPointSize = 18;

  /// See [symbolPointSize].
  static const String symbolWeight = 'medium';

  /// See [symbolPointSize].
  static const String symbolScale = 'large';

  /// How far above the icon box's centre a symbol's alignment centre sits
  /// (SwiftUI `TabView`, iOS 26.4: 2 px @3x above ours at 0).
  static const double symbolRise = 2 / 3;

  /// GlassTabBarMinimizeBehavior.onScrollDown: scrolled this far down
  /// since the bar was expanded, it minimizes (SwiftUI `TabView`, iOS
  /// 26.4: 70 pt kept it, 80 pt minimized).
  static const double minimizeDistance = 75;

  /// Within this of the top the minimized bar expands again (iOS 26.4: 22
  /// pt kept it minimized, ~10 pt expanded).
  static const double minimizeExpandOffset = 15;

  /// The minimized bar: a circle this wide (iOS 26.4: 48 pt), centred
  /// on the bar's middle row ...
  static const double minimizedSize = 48;

  /// ... and this far from the screen's leading edge (its centre; iOS
  /// 26.4: 51.8 pt).
  static const double minimizedCentre = 52;

  /// The bar shrinking to its selected tab and back (iOS 26.4: the
  /// selected icon settles ~0.3 s after it starts).
  static final SpringDescription minimize = swiftUISpring(
    response: 0.4,
    dampingFraction: 1,
  );

  /// The height a tab's icon takes in the tab's column, less than
  /// [iconSize]: icon centre 60.8 pt and label ink top 78.7 pt below the
  /// bar's crop line, as SwiftUI's `TabView` (iOS 26.4, measured).
  static const double iconSlot = 25.2;

  /// The icon sits this much below the top of its slot (measured from
  /// SwiftUI `TabView`, iOS 26.4: tab icons' ink centres a third of a
  /// point lower than [iconSlot] alone puts them).
  static const double iconDrop = 1 / 3;

  /// The gap between a tab's icon slot and its label.
  static const double labelGap = 2;

  /// Beside the search tab iOS 26.4 sets every label this much further
  /// towards the end than in a bar without one (2 px at 3x on all three
  /// tabs, against the plain and accessory bars; icons do not move).
  static const double searchLabelShift = 2 / 3;

  /// A tab's label: 10 pt semibold (measured from SwiftUI `TabView`,
  /// iOS 26.4: "Settings" 39.7 pt of ink).
  static const TextStyle label = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  /// The largest text scale the floating bar's labels take: iOS tab bar
  /// labels do not grow with Dynamic Type (UIKit shows the Large Content
  /// Viewer on a long press instead).
  static const double maxTextScale = 1;

  /// The bar growing by [growX] when touched and back once the lens has
  /// settled (SwiftUI `TabView`, iOS 26.4: half grown 3.5 frames after the
  /// touch, peak 7.7 of 7.0 at frame 12; shrinking over 8 frames with a
  /// 0.7-pt undershoot). A quick tap does not grow the bar.
  static final SpringDescription grow = swiftUISpring(
    response: 0.32,
    dampingFraction: 0.6,
  );

  /// The lens popping up when a press sends it to another tab: SwiftUI's
  /// `TabView` (iOS 26.4) has it at full height 6 frames after the touch,
  /// a little over (7.3 pt above the bar against 6.0 held) at frame 8.
  static final SpringDescription pop = swiftUISpring(
    response: 0.25,
    dampingFraction: 0.7,
  );

  /// After the popped lens arrives at a tab that is still held, iOS 26.4
  /// lets it settle into the pill and lifts it again (SwiftUI `TabView`:
  /// gone 2–4 frames after arriving, growing again 6 frames later, full
  /// 12 frames after that with [press]).
  static const Duration relift = Duration(milliseconds: 60);

  /// The held lens settling on arrival (before [relift]): without the
  /// release spring's undershoot, so it shrinks to its resting size but no
  /// smaller (SwiftUI `TabView`, iOS 26.4: 65 pt tall at the dip, held
  /// 76).
  static final SpringDescription arrive = swiftUISpring(
    response: 0.2,
    dampingFraction: 1,
  );

  /// Pill to lens.
  static final SpringDescription press = swiftUISpring(
    response: 0.381,
    dampingFraction: 0.752,
  );

  /// Lens back to pill (it undershoots: the pill squashes).
  static final SpringDescription release = swiftUISpring(
    response: 0.27,
    dampingFraction: 0.55,
  );

  /// The lens following the finger. SwiftUI's `TabView` (iOS 26.4, a
  /// 0.8 s drag Home to Settings) keeps its lens within ~3 pt of ours at
  /// 0.25 over frames 20-50; 0.35 trailed it by ~12 pt.
  static final SpringDescription follow = swiftUISpring(
    response: 0.25,
    dampingFraction: 1.0,
  );

  /// The lens travelling from the selection to a pressed or tapped tab
  /// (SwiftUI `TabView`, iOS 26.4: Home to Music and Home to Settings fit
  /// response 0.36 / 0.35, damping 0.88 / 0.97, within 0.3 pt a frame).
  static final SpringDescription travel = swiftUISpring(
    response: 0.355,
    dampingFraction: 0.9,
  );

  /// The pill moving to a newly selected tab.
  static final SpringDescription slide = swiftUISpring(
    response: 0.3,
    dampingFraction: 0.78,
  );

  /// The search tab's magnifying glass, as SwiftUI's `Tab(role: .search)`
  /// draws it (measured, iOS 26.4): a square of this side, centred in the
  /// circle, holding the ring at its top leading corner and the handle's
  /// round end at its bottom trailing corner.
  static const double searchGlyph = 22.6;

  /// The ring's outer radius (measured; see [searchGlyph]).
  static const double searchRing = 9.33;

  /// The ring's stroke (measured: 2.08 pt, against 1.65 pt for
  /// CupertinoIcons.search at 26).
  static const double searchStroke = 2.08;

  /// The handle's width, with round ends (measured: about 1.45 times the
  /// ring's stroke).
  static const double searchHandle = 3.0;

  /// The bar's shadow in shader mode (measured from SwiftUI `TabView`,
  /// iOS 26.4, over white: a blurred edge 8 pt below the glass, sigma
  /// 16.9 pt, about 7 % black). See BarShadow.
  static const Offset shadowOffset = Offset(0, 8);

  /// See [shadowOffset].
  static const double shadowSigma = 16.9;

  /// See [shadowOffset].
  static const double shadowOpacity = 0.07;

  /// After a quick tap the lens stays up this long from touch-down, then
  /// shrinks into the pill wherever it is: SwiftUI's `TabView` (iOS 26.4,
  /// Home to Settings) drops it ~165 ms in, before it arrives, so it never
  /// reaches the held lens's full width or height (tabbar_motion.py, tap:
  /// 7.0 pt above the bar at most). A longer press releases at once;
  /// Reduce Motion skips it.
  static const Duration tapHold = Duration(milliseconds: 165);

  /// A quick tap's travelling lens heads for this share of the held
  /// lens's size from touch-up until it settles (SwiftUI's `TabView`, iOS
  /// 26.4: 7.0 pt over the bar at most).
  static const double tapLift = 0.93;

  /// After a quick tap on another tab the new pill fades in over this,
  /// from the lens starting to settle: SwiftUI's `TabView` (iOS 26.4)
  /// shows nothing there for ~130 ms after the lens starts settling, then
  /// fades the pill in over ~140 ms (tabbar_light.py, tap).
  static const Duration tapPillIn = Duration(milliseconds: 280);

  /// A quick tap's lens settling into the pill: softer than [release]
  /// (iOS 26.4 takes ~6 frames from 7 pt above the bar, not 4).
  static final SpringDescription tapSettle = swiftUISpring(
    response: 0.35,
    dampingFraction: 0.7,
  );

  /// Vibrant labels (shader glass), fitted per pixel to iOS 26.4 over a
  /// photo: a glyph's lightness is its own plus this gain times the glass
  /// lightness's distance from [vibrancyReference] (the glass over a plain
  /// page, where a glyph has its own colour; both 0-1), and it takes
  /// [vibrancyChromaGain] of the glass's hue.
  static const double vibrancyLightnessGain = 0.065;

  /// See [vibrancyLightnessGain].
  static const double vibrancyReference = 0.992;

  /// See [vibrancyLightnessGain].
  static const double vibrancyChromaGain = 1;

  /// [vibrancyLightnessGain] in dark mode.
  static const double vibrancyLightnessGainDark = -0.03;

  /// [vibrancyReference] in dark mode.
  static const double vibrancyReferenceDark = 0.075;

  /// [vibrancyChromaGain] in dark mode.
  static const double vibrancyChromaGainDark = 0.37;

  /// The selected tint over shader glass: each channel moves by this share
  /// of the glass's change from [tintVibrancyReference] (the pill over a
  /// plain page; iOS 26.4 over a photo: 0.525 light, 0.463 dark).
  static const double tintVibrancyGain = 0.5;

  /// See [tintVibrancyGain].
  static const double tintVibrancyReference = 0.922;

  /// [tintVibrancyReference] in dark mode.
  static const double tintVibrancyReferenceDark = 0.208;

  /// The selected pill over shader glass: the glass under it becomes
  /// [pillVibrancyScale] times itself raised to [pillVibrancyGamma], so it
  /// darkens more where the glass is darker (iOS 26.4: 235 over white, ~15
  /// darker than a flat grey over a photo; the scale puts the pill over a
  /// white page at iOS's 235).
  static const double pillVibrancyScale = 0.932;

  /// See [pillVibrancyScale].
  static const double pillVibrancyGamma = 1.3;

  /// In dark mode the pill lifts the glass: scale, gamma and an added
  /// [pillVibrancyLiftDark] (iOS 26.4 over a photo: 0.877 x + 0.159, the lift set so the pill over
  /// a black page reads iOS's 53).
  static const double pillVibrancyScaleDark = 0.877;

  /// See [pillVibrancyScaleDark].
  static const double pillVibrancyGammaDark = 1;

  /// See [pillVibrancyScaleDark].
  static const double pillVibrancyLiftDark = 0.139;

  /// The lens content's motion blur: this many times the lens's travel per
  /// 60 Hz frame. 0: iOS 26.4 keeps the tabs inside a sliding lens crisp
  /// (its sharpness dip over a drag comes from the lens's ends smearing
  /// what they pass); a blur showed as ghost copies of the icon.
  static const double lensMotionBlur = 0;

  /// The longest motion blur (logical px).
  static const double lensMotionBlurMax = 24;
}

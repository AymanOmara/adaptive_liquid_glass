import 'package:flutter/cupertino.dart';

import '../core/swiftui_spring.dart';

/// Measured from iOS 26.4's tab bar (Kept, iPhone 17 Pro) by frame-by-frame
/// tracking of press, hold, drag and release (`example/lib/tab_bar_probe.dart`
/// lays the bar out the same way).
abstract final class TabBarMetrics {
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

  /// The held lens over the pill: 114.3 by 74 against 93.7 by 54.
  static const double lensGrowX = 20.6;

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

  /// Peak white of the light a held lens casts on the bar (see BarGlow).
  static const double glow = 0.095;

  /// The bar's light coming on (press, drag) and fading after release
  /// (Kept: about a third left 16 frames after letting go).
  static final SpringDescription light = swiftUISpring(
    response: 0.3,
    dampingFraction: 1,
  );

  /// See [light].
  static final SpringDescription lightOff = swiftUISpring(
    response: 0.45,
    dampingFraction: 1,
  );

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

  /// A tab's label: 10 pt semibold (measured from SwiftUI `TabView`,
  /// iOS 26.4: "Settings" 39.7 pt of ink).
  static const TextStyle label = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

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
  static const Duration relift = Duration(milliseconds: 100);

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

  /// The lens following the finger.
  static final SpringDescription follow = swiftUISpring(
    response: 0.35,
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
  /// Home to Settings) drops it ~150 ms in, before it arrives, so it never
  /// reaches the held lens's full width or height (tabbar_motion.py, tap).
  /// A longer press releases at once; Reduce Motion skips it.
  static const Duration tapHold = Duration(milliseconds: 150);
}

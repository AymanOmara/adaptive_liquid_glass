# Phase 2a — GlassButton and the navigation bar — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `GlassButton` (SwiftUI's full glass button vocabulary), `GlassBackButton`, `GlassNavigationBar` (inline) and `SliverGlassNavigationBar` (collapsing large title), measured against SwiftUI on iOS and stock Material 3 on Android.

**Architecture:** Every component is composed from the existing `LiquidGlass` / `GlassGroup` (no new rendering code). A small `GlassModeBuilder` resolves the render path once so each component branches to its Material 3 counterpart. Metrics come from SwiftUI reference screens added to the example's existing `-renderer swiftui` host; a JSON file of measured values is committed and the Dart constants are tested against it.

**Tech Stack:** Flutter ≥ 3.32 / Dart ≥ 3.8, `flutter_test`, SwiftUI (iOS 26) reference host in `example/ios/Runner`, Python 3 measurement in `tool/fidelity/.venv` (numpy, Pillow).

**Spec:** `docs/superpowers/specs/2026-10-05-phase2-button-navbar-design.md`

## Global Constraints

- Flutter **≥ 3.32**, Dart **≥ 3.8**; no runtime dependencies beyond the Flutter SDK.
- App code never branches on platform; `GlassRenderMode` (`auto | shader | native | material`) picks the path, `material` renders stock Material 3.
- Reference simulator: **iPhone 17 Pro, iOS 26.4** (UDID `2AC3AF21-6F97-4706-AE23-3F507BE9699F`), 402 × 874 pt, 3×.
- RTL-safe: `EdgeInsetsDirectional` / `AlignmentDirectional` / `PositionedDirectional` only; back chevron mirrors; actions at the end, large title at the start.
- Accent = `CupertinoTheme.of(context).primaryColor`; destructive = `CupertinoColors.systemRed`; resolve dynamic colours with `CupertinoDynamicColor.resolve`.
- Public types exported from `lib/adaptive_liquid_glass.dart`; everything else stays in `lib/src/`.
- Never run `pub publish` (memory rule).
- Commit after each task; end commit messages with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Toggling `loading` on a button** — width and height must not change between `loading: false` and `true` (no layout shift). Pinned in Task 3.
2. **Long title with several actions** — the inline title truncates with an ellipsis and never overflows, in LTR and RTL. Pinned in Task 6.
3. **Root route (cannot pop)** — no back button is shown; a pushed route shows one and popping works. Pinned in Task 5.
4. **Large text scale (`TextScaler.linear(2)`)** — buttons grow taller instead of clipping their label; the large title grows. Pinned in Tasks 2 and 8.
5. **Icon-only button without a label** — still announced by screen readers via `semanticLabel`; disabled buttons are announced as disabled buttons. Pinned in Tasks 2 and 3.

---

## File Structure

```
lib/src/core/glass_mode_builder.dart          resolves EffectiveGlassMode for a subtree (Task 2)
lib/src/group/glass_union_scope.dart          default unionId for LiquidGlass below (Task 6)
lib/src/button/button_metrics.dart            per-size metrics (measured) (Task 2)
lib/src/button/glass_button.dart              GlassButton + enums + GlassControlSizeScope (Tasks 2-3)
lib/src/button/material_glass_button.dart     Material 3 mapping (Task 4)
lib/src/navigation/nav_bar_metrics.dart       bar metrics (measured) (Task 6)
lib/src/navigation/glass_back_button.dart     (Task 5)
lib/src/navigation/scroll_edge.dart           scroll edge gradient (Task 6)
lib/src/navigation/nav_bar_content.dart       leading/title/actions row shared by both bars (Task 6)
lib/src/navigation/glass_navigation_bar.dart  inline bar (Tasks 6-7)
lib/src/navigation/sliver_glass_navigation_bar.dart  large title (Task 8)
tool/reference/controls.json                  measured SwiftUI metrics (Task 1)
tool/reference/measure_controls.py            measurement script (Task 1)
example/ios/Runner/ControlScenes.swift        SwiftUI reference screens (Task 1)
test/button/…, test/navigation/…
```

---

### Task 1: SwiftUI reference screens and measured metrics

**Files:**
- Create: `example/ios/Runner/ControlScenes.swift`
- Modify: `example/ios/Runner/SceneDelegate.swift`
- Create: `tool/reference/measure_controls.py`
- Create: `tool/reference/controls.json` (output of the script)
- Create: `tool/reference/README.md`

**Interfaces:**
- Produces: `tool/reference/controls.json` with exactly this shape (numbers in points):

```json
{
  "buttons": {
    "mini":       {"height": 0, "padding": 0, "font": 0, "icon_only": 0},
    "small":      {"height": 0, "padding": 0, "font": 0, "icon_only": 0},
    "regular":    {"height": 0, "padding": 0, "font": 0, "icon_only": 0},
    "large":      {"height": 0, "padding": 0, "font": 0, "icon_only": 0},
    "extraLarge": {"height": 0, "padding": 0, "font": 0, "icon_only": 0}
  },
  "navbar": {
    "bar_height": 0, "button": 0, "edge_inset": 0, "group_gap": 0,
    "large_title_height": 0, "large_title_inset": 0,
    "inline_fade_start": 0, "inline_fade_end": 0
  }
}
```

- [ ] **Step 1: Add the SwiftUI reference screens**

`example/ios/Runner/ControlScenes.swift`:

```swift
import SwiftUI
import UIKit

/// `-controls buttons` and `-controls navbar [-scrollY <pt>]`: SwiftUI
/// reference screens for Phase 2a metrics (tool/reference/).
enum ControlScenes {
  static func install(in window: UIWindow?) -> Bool {
    guard #available(iOS 26.0, *), let which = LaunchArgs.arg("controls") else { return false }
    let root: AnyView
    switch which {
    case "buttons": root = AnyView(ButtonsReference())
    case "navbar":
      let y = Double(LaunchArgs.arg("scrollY") ?? "0") ?? 0
      root = AnyView(NavBarReference(scrollY: y))
    default: return false
    }
    window?.rootViewController = UIHostingController(rootView: root)
    window?.makeKeyAndVisible()
    return true
  }
}

/// One row per control size, top to bottom mini…extraLarge, each 120 pt
/// apart starting at y = 80: a "Button" label button at x = 30 and an
/// icon-only button at x = 300. Mid-grey background so glass edges show.
@available(iOS 26.0, *)
struct ButtonsReference: View {
  let sizes: [ControlSize] = [.mini, .small, .regular, .large, .extraLarge]
  var body: some View {
    ZStack(alignment: .topLeading) {
      Color(white: 0.5).ignoresSafeArea()
      ForEach(sizes.indices, id: \.self) { i in
        HStack(spacing: 0) {
          Button("Button") {}.buttonStyle(.glass).controlSize(sizes[i])
            .fixedSize()
            .frame(width: 270, alignment: .leading)
          Button {} label: { Image(systemName: "plus") }
            .buttonStyle(.glass).controlSize(sizes[i]).fixedSize()
        }
        .padding(.leading, 30)
        .frame(height: 100)
        .offset(y: 80 + Double(i) * 120 - 50)
      }
    }
    .environment(\.colorScheme, .light)
    .statusBarHidden(true)
  }
}

/// A large-title list scrolled to `scrollY`, two trailing toolbar buttons.
@available(iOS 26.0, *)
struct NavBarReference: View {
  let scrollY: Double
  @State private var position = ScrollPosition(y: 0)
  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(0..<60) { i in
            Text("Row \(i)").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
              .padding(.horizontal, 16)
          }
        }
      }
      .scrollPosition($position)
      .onAppear { position = ScrollPosition(y: scrollY) }
      .navigationTitle("Inbox")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          Button {} label: { Image(systemName: "square.and.pencil") }
          Button {} label: { Image(systemName: "ellipsis") }
        }
      }
    }
    .environment(\.colorScheme, .light)
  }
}
```

In `example/ios/Runner/SceneDelegate.swift` replace the install line with:

```swift
    if !ControlScenes.install(in: window) && !MotionScenes.install(in: window) {
      LaunchArgs.installReferenceScene(in: window)
    }
```

Add `ControlScenes.swift` to the Runner target (open `example/ios/Runner.xcodeproj` membership via the same pattern as `MotionScenes.swift`: add a `PBXFileReference`, `PBXBuildFile` and an entry in the Runner `Sources` build phase in `example/ios/Runner.xcodeproj/project.pbxproj`).

- [ ] **Step 2: Build and capture**

```bash
cd example && flutter build ios --simulator --debug && cd ..
UDID=2AC3AF21-6F97-4706-AE23-3F507BE9699F
APP=example/build/ios/iphonesimulator/Runner.app
xcrun simctl install $UDID $APP
mkdir -p build/reference
xcrun simctl launch --terminate-running-process $UDID com.aymanomara.adaptiveLiquidGlassExample -controls buttons; sleep 3
xcrun simctl io $UDID screenshot build/reference/buttons.png
for y in 0 10 20 30 40 50 60 70 80 100; do
  xcrun simctl launch --terminate-running-process $UDID com.aymanomara.adaptiveLiquidGlassExample -controls navbar -scrollY $y; sleep 3
  xcrun simctl io $UDID screenshot build/reference/navbar_$y.png
done
```

Expected: 11 PNGs, 1206 × 2622.

- [ ] **Step 3: Write the measurement script**

`tool/reference/measure_controls.py`:

```python
"""Measures SwiftUI reference screenshots (build/reference/) into
tool/reference/controls.json. Usage:
tool/fidelity/.venv/bin/python tool/reference/measure_controls.py build/reference
"""
import json, pathlib, sys
import numpy as np
from PIL import Image

S = 3.0  # px per pt
SIZES = ["mini", "small", "regular", "large", "extraLarge"]


def grey(p):
    return np.asarray(Image.open(p).convert("L"), dtype=np.float32)


def bbox(mask):
    ys, xs = np.where(mask)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def buttons(img):
    bg = np.median(img)
    out = {}
    for i, name in enumerate(SIZES):
        cy = int((80 + i * 120) * S)
        band = img[cy - 150:cy + 150]
        diff = np.abs(band - bg) > 6
        label = diff[:, : int(290 * S)]
        icon = diff[:, int(290 * S):]
        x0, y0, x1, y1 = bbox(label)
        ix0, iy0, ix1, iy1 = bbox(icon)
        # dark text pixels inside the label button
        text = band[y0:y1, x0:x1] < 60
        tx0, ty0, tx1, ty1 = bbox(text)
        cap = (ty1 - ty0) / S  # "Button": cap height + descender-free
        out[name] = {
            "height": round((y1 - y0) / S, 2),
            "padding": round(((x1 - x0) - (tx1 - tx0)) / 2 / S, 2),
            "font": round(cap / 0.72, 1),
            "icon_only": round((iy1 - iy0) / S, 2),
        }
    return out


def dark_bbox(img, x0, y0, x1, y1, thr=90):
    m = img[int(y0 * S):int(y1 * S), int(x0 * S):int(x1 * S)] < thr
    if not m.any():
        return None
    bx0, by0, bx1, by1 = bbox(m)
    return (x0 + bx0 / S, y0 + by0 / S, x0 + bx1 / S, y0 + by1 / S, m.sum())


def navbar(d):
    rest = grey(d / "navbar_0.png")
    # Status bar 0..62 pt; the bar sits below it. Find the trailing button
    # group (non-white blob right of x = 250 within y 62..140).
    m = np.abs(rest[int(62 * S):int(140 * S), int(250 * S):] - 255) > 8
    gx0, gy0, gx1, gy1 = bbox(m)
    button = (gy1 - gy0) / S
    bar_top, bar_bottom = 62.0, 62.0 + (gy1 - gy0) / S + 2 * ((gy0 / S))
    edge = 402 - (250 + gx1 / S)
    # Large title: dark text block below the bar, left half.
    lt = dark_bbox(rest, 0, bar_bottom, 300, bar_bottom + 80)
    large_inset, large_h = lt[0], lt[3] - bar_bottom
    # Inline title fade: dark pixel mass in the bar centre per offset.
    ys, mass = [], []
    for p in sorted(d.glob("navbar_*.png"), key=lambda p: int(p.stem.split("_")[1])):
        y = int(p.stem.split("_")[1])
        b = dark_bbox(grey(p), 140, bar_top, 262, bar_bottom)
        ys.append(y)
        mass.append(0 if b is None else b[4])
    full = max(mass) or 1
    frac = [m / full for m in mass]
    start = next(y for y, f in zip(ys, frac) if f > 0.05)
    end = next(y for y, f in zip(ys, frac) if f > 0.95)
    return {
        "bar_height": round(bar_bottom - bar_top, 2),
        "button": round(button, 2),
        "edge_inset": round(edge, 2),
        "group_gap": 0,
        "large_title_height": round(large_h, 2),
        "large_title_inset": round(large_inset, 2),
        "inline_fade_start": start,
        "inline_fade_end": end,
    }


def main():
    d = pathlib.Path(sys.argv[1])
    out = {"buttons": buttons(grey(d / "buttons.png")), "navbar": navbar(d)}
    dst = pathlib.Path(__file__).with_name("controls.json")
    dst.write_text(json.dumps(out, indent=2) + "\n")
    print(json.dumps(out, indent=2))


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run it and sanity-check**

Run: `tool/fidelity/.venv/bin/python tool/reference/measure_controls.py build/reference`
Expected: heights increase strictly mini → extraLarge; `icon_only` ≈ `height` per size (±1); navbar `bar_height` between 44 and 60; `inline_fade_start` < `inline_fade_end`. Open `build/reference/buttons.png` and one navbar PNG and confirm by eye that the bboxes match (crop with Pillow if unsure). If a check fails, fix the region constants in the script (they are the only assumptions) and re-run.

- [ ] **Step 5: Document and commit**

`tool/reference/README.md`:

```markdown
# SwiftUI reference metrics (Phase 2a)

`controls.json` holds button and navigation-bar metrics measured from
SwiftUI on iPhone 17 Pro / iOS 26.4. Re-measure: build the example, run
the capture commands in `docs/superpowers/plans/2026-10-05-phase2a-button-navbar.md`
(Task 1, Step 2), then `tool/fidelity/.venv/bin/python
tool/reference/measure_controls.py build/reference`. The Dart constants in
`lib/src/button/button_metrics.dart` and
`lib/src/navigation/nav_bar_metrics.dart` are tested against this file.
```

```bash
git add example/ios/Runner/ControlScenes.swift example/ios/Runner/SceneDelegate.swift example/ios/Runner.xcodeproj/project.pbxproj tool/reference
git commit -m "tool: SwiftUI reference screens and measured Phase 2a metrics"
```

---

### Task 2: GlassButton core (styles, roles, sizes, shapes)

**Files:**
- Create: `lib/src/core/glass_mode_builder.dart`
- Create: `lib/src/button/button_metrics.dart`
- Create: `lib/src/button/glass_button.dart`
- Modify: `lib/adaptive_liquid_glass.dart` (export)
- Test: `test/button/glass_button_test.dart`, `test/button/button_metrics_test.dart`

**Interfaces:**
- Consumes: `LiquidGlass`, `Glass`, `GlassShape`, `GlassRenderMode`, `resolveGlassMode`, `EffectiveGlassMode`, `GlassPlatform.instance.environment`, `LiquidGlassTheme`; `tool/reference/controls.json` (Task 1).
- Produces:
  - `enum GlassButtonStyle { glass, glassProminent }`
  - `enum GlassButtonRole { none, destructive, cancel }`
  - `enum GlassControlSize { mini, small, regular, large, extraLarge }`
  - `enum GlassButtonShape { automatic, capsule, circle, roundedRect }`
  - `class GlassControlSizeScope extends InheritedWidget { const GlassControlSizeScope({required GlassControlSize size, required Widget child}); static GlassControlSize? maybeOf(BuildContext); }`
  - `class GlassButton extends StatelessWidget` with constructors `GlassButton({Key?, required VoidCallback? onPressed, GlassButtonStyle style = GlassButtonStyle.glass, GlassButtonRole role = GlassButtonRole.none, GlassControlSize? size, GlassButtonShape shape = GlassButtonShape.automatic, bool loading = false, String loadingLabel = 'loading', Color? tint, GlassRenderMode? mode, Object? glassId, String? semanticLabel, required Widget child})` and `GlassButton.icon({..., required IconData icon, Widget? label, ...same named params, no child})`.
  - `class GlassModeBuilder extends StatelessWidget { const GlassModeBuilder({GlassRenderMode? mode, required Widget Function(BuildContext, EffectiveGlassMode) builder}); }`
  - `class GlassButtonMetrics { final double height, padding, fontSize, iconSize, iconGap, cornerRadius; }` and `GlassButtonMetrics glassButtonMetrics(GlassControlSize)`.

- [ ] **Step 1: Write the failing metrics test**

`test/button/button_metrics_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/button/button_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final json =
      jsonDecode(File('tool/reference/controls.json').readAsStringSync())
          as Map<String, dynamic>;
  final buttons = json['buttons'] as Map<String, dynamic>;

  for (final size in GlassControlSize.values) {
    test('${size.name} matches SwiftUI', () {
      final m = glassButtonMetrics(size);
      final ref = buttons[size.name] as Map<String, dynamic>;
      expect(m.height, moreOrLessEquals((ref['height'] as num).toDouble(), epsilon: 0.5));
      expect(m.padding, moreOrLessEquals((ref['padding'] as num).toDouble(), epsilon: 1));
      expect(m.fontSize, moreOrLessEquals((ref['font'] as num).toDouble(), epsilon: 1));
    });
  }

  test('sizes grow', () {
    final h = [for (final s in GlassControlSize.values) glassButtonMetrics(s).height];
    for (var i = 1; i < h.length; i++) {
      expect(h[i], greaterThan(h[i - 1]));
    }
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/button/button_metrics_test.dart`
Expected: compilation error, `button_metrics.dart` not found.

- [ ] **Step 3: Write the metrics**

`lib/src/button/button_metrics.dart` (values below are iOS 26 estimates; replace each with `controls.json` until Step 4 passes — the test is the source of truth):

```dart
import '../button/glass_button.dart' show GlassControlSize;

/// Layout of a glass button at one control size, measured from SwiftUI's
/// `.buttonStyle(.glass)` on iOS 26.4 (`tool/reference/controls.json`).
class GlassButtonMetrics {
  const GlassButtonMetrics({
    required this.height,
    required this.padding,
    required this.fontSize,
    required this.iconSize,
    required this.iconGap,
    required this.cornerRadius,
  });

  /// Height of the button (and diameter when icon-only).
  final double height;

  /// Horizontal space between the glass edge and the label.
  final double padding;

  /// Label font size.
  final double fontSize;

  /// Icon size.
  final double iconSize;

  /// Space between an icon and a label.
  final double iconGap;

  /// Corner radius for [GlassButtonShape.roundedRect].
  final double cornerRadius;
}

const _metrics = <GlassControlSize, GlassButtonMetrics>{
  GlassControlSize.mini: GlassButtonMetrics(
    height: 24, padding: 8, fontSize: 12, iconSize: 12, iconGap: 4, cornerRadius: 6,
  ),
  GlassControlSize.small: GlassButtonMetrics(
    height: 28, padding: 10, fontSize: 13, iconSize: 14, iconGap: 4, cornerRadius: 8,
  ),
  GlassControlSize.regular: GlassButtonMetrics(
    height: 34, padding: 12, fontSize: 15, iconSize: 16, iconGap: 6, cornerRadius: 10,
  ),
  GlassControlSize.large: GlassButtonMetrics(
    height: 44, padding: 16, fontSize: 17, iconSize: 20, iconGap: 6, cornerRadius: 12,
  ),
  GlassControlSize.extraLarge: GlassButtonMetrics(
    height: 52, padding: 20, fontSize: 17, iconSize: 22, iconGap: 8, cornerRadius: 14,
  ),
};

/// Metrics for [size].
GlassButtonMetrics glassButtonMetrics(GlassControlSize size) => _metrics[size]!;
```

`lib/src/core/glass_mode_builder.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../platform/glass_platform.dart';
import 'glass_environment.dart';
import 'glass_render_mode.dart';
import 'render_mode_resolver.dart';
import 'theme.dart';

/// Builds with the rendering path [mode] resolves to here (the theme's
/// default when null), rebuilding when the platform environment changes.
class GlassModeBuilder extends StatelessWidget {
  const GlassModeBuilder({super.key, this.mode, required this.builder});

  final GlassRenderMode? mode;
  final Widget Function(BuildContext context, EffectiveGlassMode mode) builder;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<GlassEnvironment>(
        valueListenable: GlassPlatform.instance.environment,
        builder: (context, environment, _) => builder(
          context,
          resolveGlassMode(
            requested: mode ?? LiquidGlassTheme.of(context).defaultMode,
            environment: environment,
          ),
        ),
      );
}
```

- [ ] **Step 4: Run the metrics test until it passes**

Run: `flutter test test/button/button_metrics_test.dart` — edit the numbers in `_metrics` to the measured ones until PASS (keep `iconSize`, `iconGap`, `cornerRadius` as above unless `controls.json` says otherwise).

- [ ] **Step 5: Write the failing widget tests**

`test/button/glass_button_test.dart`:

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/button/button_metrics.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

LiquidGlass glassOf(WidgetTester t) =>
    t.widget<LiquidGlass>(find.byType(LiquidGlass));

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  for (final size in GlassControlSize.values) {
    testWidgets('${size.name}: height and padding follow the metrics', (t) async {
      shaderEnv();
      await t.pumpWidget(plainHost(
        GlassButton(onPressed: () {}, size: size, child: const Text('Button')),
      ));
      final m = glassButtonMetrics(size);
      final button = t.getSize(find.byType(GlassButton));
      final text = t.getSize(find.text('Button'));
      expect(button.height, moreOrLessEquals(m.height, epsilon: 0.01));
      expect((button.width - text.width) / 2, moreOrLessEquals(m.padding, epsilon: 0.01));
    }, variant: ios);
  }

  testWidgets('automatic shape: capsule for a label, circle for an icon', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(Column(children: [
      GlassButton(onPressed: () {}, child: const Text('A')),
      GlassButton.icon(onPressed: () {}, icon: CupertinoIcons.add),
    ])));
    final glasses = t.widgetList<LiquidGlass>(find.byType(LiquidGlass)).toList();
    expect(glasses[0].shape, const GlassShape.capsule());
    expect(glasses[1].shape, const GlassShape.circle());
    final icon = t.getSize(find.byType(GlassButton).last);
    expect(icon.width, icon.height);
  }, variant: ios);

  testWidgets('roundedRect uses the size corner radius', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(GlassButton(
      onPressed: () {},
      shape: GlassButtonShape.roundedRect,
      child: const Text('A'),
    )));
    expect(glassOf(t).shape,
        GlassShape.rect(glassButtonMetrics(GlassControlSize.regular).cornerRadius));
  }, variant: ios);

  testWidgets('prominent is tinted with the accent, label white', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(GlassButton(
      onPressed: () {},
      style: GlassButtonStyle.glassProminent,
      child: const Text('Go'),
    )));
    expect(glassOf(t).glass.tintColor, CupertinoColors.systemBlue.color);
    expect(DefaultTextStyle.of(t.element(find.text('Go'))).style.color,
        const Color(0xFFFFFFFF));
  }, variant: ios);

  testWidgets('destructive: red label on glass, red tint when prominent', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(Column(children: [
      GlassButton(onPressed: () {}, role: GlassButtonRole.destructive, child: const Text('Delete')),
      GlassButton(
        onPressed: () {},
        role: GlassButtonRole.destructive,
        style: GlassButtonStyle.glassProminent,
        child: const Text('Erase'),
      ),
    ])));
    expect(DefaultTextStyle.of(t.element(find.text('Delete'))).style.color,
        CupertinoColors.systemRed.color);
    final glasses = t.widgetList<LiquidGlass>(find.byType(LiquidGlass)).toList();
    expect(glasses[1].glass.tintColor, CupertinoColors.systemRed.color);
  }, variant: ios);

  testWidgets('cancel is semibold', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(GlassButton(
      onPressed: () {}, role: GlassButtonRole.cancel, child: const Text('Cancel'),
    )));
    expect(DefaultTextStyle.of(t.element(find.text('Cancel'))).style.fontWeight,
        FontWeight.w600);
  }, variant: ios);

  testWidgets('tapping calls onPressed; glassId is forwarded', (t) async {
    shaderEnv();
    var taps = 0;
    await t.pumpWidget(plainHost(GlassButton(
      onPressed: () => taps++, glassId: 'save', child: const Text('Save'),
    )));
    await t.tap(find.text('Save'));
    expect(taps, 1);
    expect(glassOf(t).glassId, 'save');
  }, variant: ios);

  testWidgets('GlassControlSizeScope sets the default size', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(GlassControlSizeScope(
      size: GlassControlSize.large,
      child: GlassButton(onPressed: () {}, child: const Text('A')),
    )));
    expect(t.getSize(find.byType(GlassButton)).height,
        glassButtonMetrics(GlassControlSize.large).height);
  }, variant: ios);

  testWidgets('icon-only button is announced by its semanticLabel', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(plainHost(GlassButton.icon(
      onPressed: () {}, icon: CupertinoIcons.share, semanticLabel: 'Share',
    )));
    expect(find.bySemanticsLabel('Share'), findsOneWidget);
    s.dispose();
  }, variant: ios);

  testWidgets('large text grows the button instead of clipping', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(MediaQuery.withClampedTextScaling(
      minScaleFactor: 2, maxScaleFactor: 2,
      child: GlassButton(onPressed: () {}, child: const Text('Button')),
    )));
    expect(t.takeException(), isNull);
    expect(t.getSize(find.byType(GlassButton)).height,
        greaterThan(glassButtonMetrics(GlassControlSize.regular).height));
  }, variant: ios);
}
```

- [ ] **Step 6: Run to verify they fail**

Run: `flutter test test/button/glass_button_test.dart`
Expected: compile errors (`GlassButton` undefined).

- [ ] **Step 7: Implement GlassButton (glass path)**

`lib/src/button/glass_button.dart`:

```dart
import 'package:flutter/cupertino.dart';

import '../core/glass.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_shape.dart';
import '../core/render_mode_resolver.dart';
import '../liquid_glass.dart';
import 'button_metrics.dart';
import 'material_glass_button.dart';

/// SwiftUI's glass button styles.
enum GlassButtonStyle {
  /// `.glass`: plain interactive glass with a readable label.
  glass,

  /// `.glassProminent`: glass tinted with the accent, white label.
  glassProminent,
}

/// SwiftUI's button roles.
enum GlassButtonRole { none, destructive, cancel }

/// SwiftUI's `ControlSize`.
enum GlassControlSize { mini, small, regular, large, extraLarge }

/// SwiftUI's `ButtonBorderShape` for glass buttons.
enum GlassButtonShape { automatic, capsule, circle, roundedRect }

/// The default [GlassControlSize] for glass buttons below it, like
/// SwiftUI's `.controlSize(_:)` modifier.
class GlassControlSizeScope extends InheritedWidget {
  const GlassControlSizeScope({super.key, required this.size, required super.child});

  final GlassControlSize size;

  static GlassControlSize? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassControlSizeScope>()?.size;

  @override
  bool updateShouldNotify(GlassControlSizeScope old) => old.size != size;
}

/// A SwiftUI glass button: `.buttonStyle(.glass)` or `.glassProminent`.
///
/// ```dart
/// GlassButton(onPressed: save, child: const Text('Save'))
/// GlassButton.icon(onPressed: share, icon: CupertinoIcons.share, semanticLabel: 'Share')
/// ```
///
/// Built on [LiquidGlass], so it joins an enclosing `GlassGroup` and morphs
/// with [glassId]. On the Material path it is a Material 3 button.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.onPressed,
    this.style = GlassButtonStyle.glass,
    this.role = GlassButtonRole.none,
    this.size,
    this.shape = GlassButtonShape.automatic,
    this.loading = false,
    this.loadingLabel = 'loading',
    this.tint,
    this.mode,
    this.glassId,
    this.semanticLabel,
    required Widget this.child,
  }) : icon = null,
       label = null;

  const GlassButton.icon({
    super.key,
    required this.onPressed,
    required IconData this.icon,
    this.label,
    this.style = GlassButtonStyle.glass,
    this.role = GlassButtonRole.none,
    this.size,
    this.shape = GlassButtonShape.automatic,
    this.loading = false,
    this.loadingLabel = 'loading',
    this.tint,
    this.mode,
    this.glassId,
    this.semanticLabel,
  }) : child = null;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final GlassButtonStyle style;
  final GlassButtonRole role;

  /// Defaults to the enclosing [GlassControlSizeScope], else regular.
  final GlassControlSize? size;
  final GlassButtonShape shape;

  /// Shows an activity indicator in place of the content and ignores taps.
  final bool loading;

  /// Read after the label while [loading].
  final String loadingLabel;

  /// The prominent fill (and the role's colour wins over it for
  /// destructive). Defaults to the accent colour.
  final Color? tint;
  final GlassRenderMode? mode;
  final Object? glassId;

  /// The accessibility label; required in practice for icon-only buttons.
  final String? semanticLabel;
  final Widget? child;
  final IconData? icon;
  final Widget? label;

  bool get _iconOnly => icon != null && label == null;

  /// Whether taps do anything.
  bool get active => onPressed != null && !loading;

  GlassShape _shape(GlassButtonMetrics m) => switch (shape) {
    GlassButtonShape.automatic =>
      _iconOnly ? const GlassShape.circle() : const GlassShape.capsule(),
    GlassButtonShape.capsule => const GlassShape.capsule(),
    GlassButtonShape.circle => const GlassShape.circle(),
    GlassButtonShape.roundedRect => GlassShape.rect(m.cornerRadius),
  };

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) => effective == EffectiveGlassMode.material
        ? MaterialGlassButton(button: this, size: _size(context))
        : _glass(context),
  );

  GlassControlSize _size(BuildContext context) =>
      size ?? GlassControlSizeScope.maybeOf(context) ?? GlassControlSize.regular;

  Widget _glass(BuildContext context) {
    final m = glassButtonMetrics(_size(context));
    final red = CupertinoDynamicColor.resolve(CupertinoColors.systemRed, context);
    final accent = CupertinoDynamicColor.resolve(
      role == GlassButtonRole.destructive
          ? CupertinoColors.systemRed
          : tint ?? CupertinoTheme.of(context).primaryColor,
      context,
    );
    final prominent = style == GlassButtonStyle.glassProminent;
    final Color? labelColor = prominent
        ? const Color(0xFFFFFFFF)
        : role == GlassButtonRole.destructive
        ? red
        : null;
    final glass = (prominent ? Glass.regular.tint(accent) : Glass.regular)
        .interactive(active);
    final textScale = MediaQuery.textScalerOf(context).scale(m.fontSize) / m.fontSize;

    Widget content = _content(m);
    if (loading) {
      content = Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: 0, alwaysIncludeSemantics: true, child: content),
          CupertinoActivityIndicator(radius: m.fontSize * 0.5, color: labelColor),
        ],
      );
    } else if (onPressed == null) {
      content = Opacity(opacity: 0.5, child: content);
    }

    content = DefaultTextStyle.merge(
      style: TextStyle(
        fontSize: m.fontSize,
        fontWeight: role == GlassButtonRole.cancel ? FontWeight.w600 : FontWeight.w500,
        color: labelColor,
      ),
      maxLines: 1,
      child: IconTheme.merge(
        data: IconThemeData(size: m.iconSize, color: labelColor),
        child: content,
      ),
    );

    Widget button = LiquidGlass(
      glass: glass,
      shape: _shape(m),
      glassId: glassId,
      mode: mode,
      onPressed: active ? onPressed : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: m.height * textScale,
          minWidth: _iconOnly ? m.height * textScale : 0,
        ),
        child: Padding(
          padding: _iconOnly
              ? EdgeInsets.zero
              : EdgeInsetsDirectional.symmetric(horizontal: m.padding),
          child: Center(widthFactor: 1, heightFactor: 1, child: content),
        ),
      ),
    );
    button = Semantics(
      label: semanticLabel,
      value: loading ? loadingLabel : null,
      child: button,
    );
    // LiquidGlass gives button semantics only when it has onPressed; a
    // disabled or loading GlassButton is still a (disabled) button.
    if (!active) {
      button = Semantics(container: true, button: true, enabled: false, child: button);
    }
    return button;
  }

  Widget _content(GlassButtonMetrics m) {
    if (child != null) return child!;
    final i = Icon(icon);
    if (label == null) return i;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [i, SizedBox(width: m.iconGap), label!],
    );
  }
}
```

Create a stub `lib/src/button/material_glass_button.dart` so it compiles (Task 4 replaces it):

```dart
import 'package:flutter/material.dart';

import 'glass_button.dart';

/// Material 3 rendering of a [GlassButton] (Task 4).
class MaterialGlassButton extends StatelessWidget {
  const MaterialGlassButton({super.key, required this.button, required this.size});

  final GlassButton button;
  final GlassControlSize size;

  @override
  Widget build(BuildContext context) => FilledButton.tonal(
    onPressed: button.active ? button.onPressed : null,
    child: button.child ?? Icon(button.icon),
  );
}
```

In `lib/adaptive_liquid_glass.dart` add:

```dart
export 'src/button/glass_button.dart';
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/button`
Expected: PASS (all tests in both files).

- [ ] **Step 9: Commit**

```bash
git add lib/src/core/glass_mode_builder.dart lib/src/button lib/adaptive_liquid_glass.dart test/button
git commit -m "feat: GlassButton — glass and prominent styles, roles, sizes, shapes"
```

---

### Task 3: Disabled and loading states

**Files:**
- Modify: `lib/src/button/glass_button.dart` (only if a test below fails)
- Test: `test/button/glass_button_states_test.dart`

**Interfaces:**
- Consumes: `GlassButton` from Task 2 (`active`, `loading`, `loadingLabel`).

- [ ] **Step 1: Write the tests**

`test/button/glass_button_states_test.dart`:

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('disabled: no tap, dimmed, announced as a disabled button', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(plainHost(
      const GlassButton(onPressed: null, child: Text('Save')),
    ));
    expect(t.widget<LiquidGlass>(find.byType(LiquidGlass)).onPressed, isNull);
    expect(t.widget<LiquidGlass>(find.byType(LiquidGlass)).glass.isInteractive, isFalse);
    expect(
      t.getSemantics(find.byType(GlassButton)),
      matchesSemantics(label: 'Save', isButton: true, hasEnabledState: true, isEnabled: false),
    );
    s.dispose();
  }, variant: ios);

  testWidgets('loading: indicator, taps ignored, label + loading read', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    var taps = 0;
    await t.pumpWidget(plainHost(GlassButton(
      onPressed: () => taps++, loading: true, child: const Text('Save'),
    )));
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    await t.tap(find.byType(GlassButton));
    expect(taps, 0);
    expect(
      t.getSemantics(find.byType(GlassButton)),
      matchesSemantics(
        label: 'Save', value: 'loading', isButton: true,
        hasEnabledState: true, isEnabled: false,
      ),
    );
    s.dispose();
  }, variant: ios);

  testWidgets('toggling loading does not change the size', (t) async {
    shaderEnv();
    Widget button(bool loading) => plainHost(GlassButton(
      onPressed: () {}, loading: loading, child: const Text('Continue'),
    ));
    await t.pumpWidget(button(false));
    final before = t.getSize(find.byType(GlassButton));
    await t.pumpWidget(button(true));
    expect(t.getSize(find.byType(GlassButton)), before);
  }, variant: ios);
}
```

- [ ] **Step 2: Run**

Run: `flutter test test/button/glass_button_states_test.dart`
Expected: PASS if Task 2 is correct. If `matchesSemantics` shows duplicate nodes (the inner `LiquidGlass` semantics plus the outer container), merge them by wrapping the `LiquidGlass` in `MergeSemantics` inside the `!active` branch, then re-run until PASS.

- [ ] **Step 3: Commit**

```bash
git add test/button/glass_button_states_test.dart lib/src/button/glass_button.dart
git commit -m "test: GlassButton disabled and loading states"
```

---

### Task 4: GlassButton on the Material path

**Files:**
- Modify: `lib/src/button/material_glass_button.dart` (replace stub)
- Test: `test/button/material_glass_button_test.dart`

**Interfaces:**
- Consumes: `GlassButton` fields (`style`, `role`, `shape`, `loading`, `loadingLabel`, `tint`, `semanticLabel`, `child`, `icon`, `label`, `active`, `onPressed`), `GlassControlSize`.
- Produces: `MaterialGlassButton({required GlassButton button, required GlassControlSize size})`; `const materialButtonHeights = {mini: 32.0, small: 36.0, regular: 40.0, large: 48.0, extraLarge: 56.0}`.

- [ ] **Step 1: Write the failing tests**

`test/button/material_glass_button_test.dart`:

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/button/material_glass_button.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

void main() {
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('glass → FilledButton.tonal, prominent → FilledButton, cancel → TextButton', (t) async {
    shaderEnv();
    await t.pumpWidget(appHost(Column(children: [
      GlassButton(onPressed: () {}, child: const Text('A')),
      GlassButton(onPressed: () {}, style: GlassButtonStyle.glassProminent, child: const Text('B')),
      GlassButton(onPressed: () {}, role: GlassButtonRole.cancel, child: const Text('C')),
    ])));
    expect(find.byType(LiquidGlass), findsNothing);
    expect(find.widgetWithText(FilledButton, 'A'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'B'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'C'), findsOneWidget);
  }, variant: android);

  testWidgets('icon-only → IconButton, sized by control size', (t) async {
    shaderEnv();
    await t.pumpWidget(appHost(GlassButton.icon(
      onPressed: () {}, icon: CupertinoIcons.add, size: GlassControlSize.large,
    )));
    expect(find.byType(IconButton), findsOneWidget);
    expect(t.getSize(find.byType(IconButton)).height,
        materialButtonHeights[GlassControlSize.large]);
  }, variant: android);

  testWidgets('destructive uses the error colours', (t) async {
    shaderEnv();
    await t.pumpWidget(appHost(GlassButton(
      onPressed: () {}, role: GlassButtonRole.destructive,
      style: GlassButtonStyle.glassProminent, child: const Text('Delete'),
    )));
    final ctx = t.element(find.text('Delete'));
    final button = t.widget<FilledButton>(find.byType(FilledButton));
    expect(button.style!.backgroundColor!.resolve({}), Theme.of(ctx).colorScheme.error);
  }, variant: android);

  testWidgets('loading shows a progress indicator and ignores taps, same size', (t) async {
    shaderEnv();
    var taps = 0;
    Widget b(bool loading) => appHost(GlassButton(
      onPressed: () => taps++, loading: loading, child: const Text('Save'),
    ));
    await t.pumpWidget(b(false));
    final size = t.getSize(find.byType(FilledButton));
    await t.pumpWidget(b(true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await t.tap(find.byType(FilledButton));
    expect(taps, 0);
    expect(t.getSize(find.byType(FilledButton)), size);
  }, variant: android);
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/button/material_glass_button_test.dart`
Expected: FAIL (`materialButtonHeights` undefined; button types wrong).

- [ ] **Step 3: Implement**

`lib/src/button/material_glass_button.dart`:

```dart
import 'package:flutter/material.dart';

import 'glass_button.dart';

/// Material 3 button heights per [GlassControlSize].
const materialButtonHeights = <GlassControlSize, double>{
  GlassControlSize.mini: 32,
  GlassControlSize.small: 36,
  GlassControlSize.regular: 40,
  GlassControlSize.large: 48,
  GlassControlSize.extraLarge: 56,
};

/// A [GlassButton] as a stock Material 3 button.
class MaterialGlassButton extends StatelessWidget {
  const MaterialGlassButton({super.key, required this.button, required this.size});

  final GlassButton button;
  final GlassControlSize size;

  @override
  Widget build(BuildContext context) {
    final b = button;
    final scheme = Theme.of(context).colorScheme;
    final h = materialButtonHeights[size]!;
    final destructive = b.role == GlassButtonRole.destructive;
    final prominent = b.style == GlassButtonStyle.glassProminent;
    final Color? background = destructive
        ? (prominent ? scheme.error : scheme.errorContainer)
        : prominent ? b.tint : null;
    final Color? foreground = destructive
        ? (prominent ? scheme.onError : scheme.onErrorContainer)
        : null;
    final OutlinedBorder? border = switch (b.shape) {
      GlassButtonShape.roundedRect => RoundedRectangleBorder(borderRadius: BorderRadius.circular(h / 4)),
      GlassButtonShape.circle => const CircleBorder(),
      _ => null,
    };
    // Loading keeps the enabled look but does nothing.
    final VoidCallback? onPressed = b.loading ? () {} : b.onPressed;

    Widget wrapLoading(Widget content) => !b.loading
        ? content
        : Stack(alignment: Alignment.center, children: [
            Opacity(opacity: 0, alwaysIncludeSemantics: true, child: content),
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
            ),
          ]);

    Widget result;
    if (b.icon != null && b.label == null) {
      final style = IconButton.styleFrom(
        fixedSize: Size.square(h),
        minimumSize: Size.square(h),
        backgroundColor: background,
        foregroundColor: foreground,
        shape: border,
      );
      final icon = wrapLoading(Icon(b.icon));
      result = switch ((b.role, b.style)) {
        (GlassButtonRole.cancel, _) => IconButton(onPressed: onPressed, style: style, icon: icon),
        (_, GlassButtonStyle.glassProminent) =>
          IconButton.filled(onPressed: onPressed, style: style, icon: icon),
        _ => IconButton.filledTonal(onPressed: onPressed, style: style, icon: icon),
      };
    } else {
      final style = ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(0, h)),
        backgroundColor: background == null ? null : WidgetStatePropertyAll(background),
        foregroundColor: foreground == null ? null : WidgetStatePropertyAll(foreground),
        shape: border == null ? null : WidgetStatePropertyAll(border),
      );
      final content = wrapLoading(b.child ??
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(b.icon), const SizedBox(width: 8), b.label!,
          ]));
      result = switch ((b.role, b.style)) {
        (GlassButtonRole.cancel, _) => TextButton(onPressed: onPressed, style: style, child: content),
        (_, GlassButtonStyle.glassProminent) =>
          FilledButton(onPressed: onPressed, style: style, child: content),
        _ => FilledButton.tonal(onPressed: onPressed, style: style, child: content),
      };
    }
    return Semantics(
      label: b.semanticLabel,
      value: b.loading ? b.loadingLabel : null,
      child: result,
    );
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/button`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/button/material_glass_button.dart test/button/material_glass_button_test.dart
git commit -m "feat: GlassButton Material 3 mapping"
```

---

### Task 5: GlassBackButton

**Files:**
- Create: `lib/src/navigation/glass_back_button.dart`
- Modify: `lib/adaptive_liquid_glass.dart`
- Test: `test/navigation/glass_back_button_test.dart`

**Interfaces:**
- Consumes: `GlassButton.icon`, `GlassModeBuilder`, `EffectiveGlassMode`.
- Produces: `GlassBackButton({Key?, VoidCallback? onPressed, GlassRenderMode? mode})`; `bool glassCanImplyBack(BuildContext context)` (true when `ModalRoute.of(context)?.impliesAppBarDismissal ?? false`).

- [ ] **Step 1: Write the failing tests**

`test/navigation/glass_back_button_test.dart`:

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget app(Widget home, {TextDirection dir = TextDirection.ltr}) => MaterialApp(
  builder: (c, child) => Directionality(textDirection: dir, child: child!),
  home: home,
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('pops the route', (t) async {
    shaderEnv();
    await t.pumpWidget(app(Builder(builder: (c) => TextButton(
      onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: GlassBackButton())),
      )),
      child: const Text('open'),
    ))));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byType(GlassBackButton), findsOneWidget);
    await t.tap(find.byType(GlassBackButton));
    await t.pumpAndSettle();
    expect(find.byType(GlassBackButton), findsNothing);
  }, variant: ios);

  testWidgets('is a circular chevron announced as Back', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(app(const Scaffold(body: Center(child: GlassBackButton()))));
    expect(find.byIcon(CupertinoIcons.chevron_back), findsOneWidget);
    expect(t.widget<LiquidGlass>(find.byType(LiquidGlass)).shape, const GlassShape.circle());
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    s.dispose();
  }, variant: ios);

  testWidgets('Material: a stock BackButton', (t) async {
    shaderEnv();
    await t.pumpWidget(app(const Scaffold(body: Center(child: GlassBackButton()))));
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byType(LiquidGlass), findsNothing);
  }, variant: android);
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/navigation/glass_back_button_test.dart`
Expected: compile error (`GlassBackButton` undefined).

- [ ] **Step 3: Implement**

`lib/src/navigation/glass_back_button.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show BackButton, MaterialLocalizations;

import '../button/glass_button.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/render_mode_resolver.dart';

/// Whether a bar on this route should show a back button.
bool glassCanImplyBack(BuildContext context) =>
    ModalRoute.of(context)?.impliesAppBarDismissal ?? false;

/// iOS 26's back button: a circular glass chevron (mirrored in RTL) that
/// pops the route. A stock [BackButton] on the Material path.
class GlassBackButton extends StatelessWidget {
  const GlassBackButton({super.key, this.onPressed, this.mode});

  /// Defaults to `Navigator.maybePop`.
  final VoidCallback? onPressed;
  final GlassRenderMode? mode;

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) {
      final pop = onPressed ?? () => Navigator.maybePop(context);
      if (effective == EffectiveGlassMode.material) {
        return BackButton(onPressed: pop);
      }
      final label = Localizations.of<MaterialLocalizations>(
            context, MaterialLocalizations)?.backButtonTooltip ??
          'Back';
      return GlassButton.icon(
        onPressed: pop,
        icon: CupertinoIcons.chevron_back,
        mode: mode,
        semanticLabel: label,
      );
    },
  );
}
```

Export in `lib/adaptive_liquid_glass.dart`:

```dart
export 'src/navigation/glass_back_button.dart' show GlassBackButton;
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/navigation/glass_back_button_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/navigation/glass_back_button.dart lib/adaptive_liquid_glass.dart test/navigation/glass_back_button_test.dart
git commit -m "feat: GlassBackButton"
```

---

### Task 6: GlassNavigationBar (inline title), glass path

**Files:**
- Create: `lib/src/group/glass_union_scope.dart`
- Modify: `lib/src/liquid_glass.dart` (default `unionId` from the scope)
- Create: `lib/src/navigation/nav_bar_metrics.dart`
- Create: `lib/src/navigation/scroll_edge.dart`
- Create: `lib/src/navigation/nav_bar_content.dart`
- Create: `lib/src/navigation/glass_navigation_bar.dart`
- Modify: `lib/adaptive_liquid_glass.dart`
- Test: `test/navigation/glass_navigation_bar_test.dart`, `test/navigation/nav_bar_metrics_test.dart`, `test/api/union_scope_test.dart`

**Interfaces:**
- Consumes: `GlassBackButton`, `glassCanImplyBack`, `GlassControlSizeScope`, `GlassControlSize`, `GlassGroup`, `GlassModeBuilder`; `tool/reference/controls.json` `navbar` block.
- Produces:
  - `class GlassUnionScope extends InheritedWidget { const GlassUnionScope({required Object id, required Widget child}); static Object? maybeOf(BuildContext); }`
  - `abstract final class NavBarMetrics { static const double barHeight, edgeInset, buttonSize, titleFontSize = 17, largeTitleFontSize = 34, largeTitleHeight, largeTitleInset, inlineFadeStart, inlineFadeEnd; static const GlassControlSize buttonControlSize; }`
  - `class GlassScrollEdge extends StatelessWidget { const GlassScrollEdge({required bool visible, required double height}); }`
  - `class NavBarContent extends StatelessWidget { const NavBarContent({Widget? leading, bool automaticallyImplyLeading = true, Widget? title, double titleOpacity = 1, List<Widget> actions = const [], GlassRenderMode? mode}); }` — the bar row (height `NavBarMetrics.barHeight`), no safe area.
  - `class GlassNavigationBar extends StatefulWidget implements PreferredSizeWidget { const GlassNavigationBar({Key?, Widget? title, Widget? leading, bool automaticallyImplyLeading = true, List<Widget> actions = const [], GlassRenderMode? mode}); }`

- [ ] **Step 1: Union scope — failing test**

`test/api/union_scope_test.dart`:

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/group/glass_member.dart';
import 'package:adaptive_liquid_glass/src/group/glass_union_scope.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hosts.dart';

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('glass below a GlassUnionScope takes its id; its own wins', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(GlassGroup(child: GlassUnionScope(
      id: 'actions',
      child: Row(mainAxisSize: MainAxisSize.min, children: const [
        SizedBox(width: 30, height: 30).glassEffect(),
        SizedBox(width: 30, height: 30).glassEffect(unionId: 'mine'),
      ].cast<Widget>()),
    ))));
    final members = t.widgetList<GlassMember>(find.byType(GlassMember)).toList();
    expect(members[0].unionId, 'actions');
    expect(members[1].unionId, 'mine');
  }, variant: ios);
}
```

Note: `glassEffect` is not const; write the children without `const` if the analyzer complains:

```dart
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: 30, height: 30).glassEffect(),
        const SizedBox(width: 30, height: 30).glassEffect(unionId: 'mine'),
      ]),
```

(use this second form).

- [ ] **Step 2: Run, verify failure**

Run: `flutter test test/api/union_scope_test.dart`
Expected: compile error (`glass_union_scope.dart` missing).

- [ ] **Step 3: Implement the scope**

`lib/src/group/glass_union_scope.dart`:

```dart
import 'package:flutter/widgets.dart';

/// Glass below without its own `unionId` merges under [id], like wrapping
/// each in `glassEffectUnion(id:)`. Used for grouped bar buttons.
class GlassUnionScope extends InheritedWidget {
  const GlassUnionScope({super.key, required this.id, required super.child});

  final Object id;

  static Object? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassUnionScope>()?.id;

  @override
  bool updateShouldNotify(GlassUnionScope old) => old.id != id;
}
```

In `lib/src/liquid_glass.dart` `build`, change `unionId: unionId,` to:

```dart
      unionId: unionId ?? GlassUnionScope.maybeOf(context),
```

and add `import 'group/glass_union_scope.dart';`.

Run: `flutter test test/api/union_scope_test.dart` → PASS. Run `flutter test` → all PASS.

- [ ] **Step 4: Metrics — failing test**

`test/navigation/nav_bar_metrics_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:adaptive_liquid_glass/src/button/button_metrics.dart';
import 'package:adaptive_liquid_glass/src/navigation/nav_bar_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final nav = (jsonDecode(File('tool/reference/controls.json').readAsStringSync())
      as Map<String, dynamic>)['navbar'] as Map<String, dynamic>;
  double ref(String k) => (nav[k] as num).toDouble();

  test('bar matches SwiftUI', () {
    expect(NavBarMetrics.barHeight, moreOrLessEquals(ref('bar_height'), epsilon: 0.5));
    expect(NavBarMetrics.edgeInset, moreOrLessEquals(ref('edge_inset'), epsilon: 1));
    expect(NavBarMetrics.largeTitleHeight, moreOrLessEquals(ref('large_title_height'), epsilon: 1));
    expect(NavBarMetrics.largeTitleInset, moreOrLessEquals(ref('large_title_inset'), epsilon: 1));
    expect(NavBarMetrics.inlineFadeStart, ref('inline_fade_start'));
    expect(NavBarMetrics.inlineFadeEnd, ref('inline_fade_end'));
  });

  test('bar buttons use a control size of the measured height', () {
    expect(glassButtonMetrics(NavBarMetrics.buttonControlSize).height,
        moreOrLessEquals(ref('button'), epsilon: 0.5));
  });
}
```

- [ ] **Step 5: Implement metrics until it passes**

`lib/src/navigation/nav_bar_metrics.dart` (estimates; set each to `controls.json` until Step 4's test passes; pick `buttonControlSize` as the size whose height equals `navbar.button`):

```dart
import '../button/glass_button.dart' show GlassControlSize;

/// iOS 26.4 navigation bar, measured from SwiftUI's `NavigationStack`
/// (`tool/reference/controls.json`).
abstract final class NavBarMetrics {
  static const double barHeight = 54;
  static const double edgeInset = 16;
  static const GlassControlSize buttonControlSize = GlassControlSize.large;
  static const double titleFontSize = 17;
  static const double largeTitleFontSize = 34;
  static const double largeTitleHeight = 52;
  static const double largeTitleInset = 16;

  /// Scroll offsets over which the inline title fades in.
  static const double inlineFadeStart = 30;
  static const double inlineFadeEnd = 50;
}
```

Run: `flutter test test/navigation/nav_bar_metrics_test.dart` → edit until PASS.

- [ ] **Step 6: Bar — failing tests**

`test/navigation/glass_navigation_bar_test.dart`:

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/group/glass_member.dart';
import 'package:adaptive_liquid_glass/src/navigation/nav_bar_metrics.dart';
import 'package:adaptive_liquid_glass/src/navigation/scroll_edge.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget page({
  Widget? title = const Text('Inbox'),
  List<Widget> actions = const [],
  TextDirection dir = TextDirection.ltr,
  Widget? body,
}) => MaterialApp(
  builder: (c, child) => Directionality(textDirection: dir, child: child!),
  home: Scaffold(
    extendBodyBehindAppBar: true,
    appBar: GlassNavigationBar(title: title, actions: actions),
    body: body ?? ListView(children: [for (var i = 0; i < 50; i++) SizedBox(height: 44, child: Text('Row $i'))]),
  ),
);

List<Widget> twoActions() => [
  GlassButton.icon(onPressed: () {}, icon: CupertinoIcons.pencil, semanticLabel: 'Edit'),
  GlassButton.icon(onPressed: () {}, icon: CupertinoIcons.ellipsis, semanticLabel: 'More'),
];

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('height is the measured bar plus the status bar', (t) async {
    shaderEnv();
    await t.pumpWidget(page());
    expect(const GlassNavigationBar().preferredSize.height, NavBarMetrics.barHeight);
  }, variant: ios);

  testWidgets('title is a centred header, 17 semibold', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(page());
    final title = find.text('Inbox');
    expect(t.getCenter(title).dx, moreOrLessEquals(400, epsilon: 1)); // 800 px test view
    final style = DefaultTextStyle.of(t.element(title)).style;
    expect(style.fontSize, NavBarMetrics.titleFontSize);
    expect(style.fontWeight, FontWeight.w600);
    expect(t.getSemantics(title), matchesSemantics(label: 'Inbox', isHeader: true));
    s.dispose();
  }, variant: ios);

  testWidgets('actions merge into one capsule at the end', (t) async {
    shaderEnv();
    await t.pumpWidget(page(actions: twoActions()));
    final members = t.widgetList<GlassMember>(find.byType(GlassMember)).toList();
    expect(members.map((m) => m.unionId).toSet(), hasLength(1));
    expect(members.first.unionId, isNotNull);
    final more = t.getRect(find.byIcon(CupertinoIcons.ellipsis));
    expect(800 - more.right, greaterThanOrEqualTo(NavBarMetrics.edgeInset));
  }, variant: ios);

  testWidgets('RTL: actions at the start edge (left)', (t) async {
    shaderEnv();
    await t.pumpWidget(page(actions: twoActions(), dir: TextDirection.rtl));
    expect(t.getCenter(find.byIcon(CupertinoIcons.ellipsis)).dx, lessThan(200));
  }, variant: ios);

  testWidgets('a long title truncates instead of overflowing', (t) async {
    shaderEnv();
    for (final dir in TextDirection.values) {
      await t.pumpWidget(page(
        title: const Text('A very long title that cannot possibly fit in the bar at all'),
        actions: twoActions(),
        dir: dir,
      ));
      expect(t.takeException(), isNull);
    }
  }, variant: ios);

  testWidgets('scroll edge shows only once content is under the bar', (t) async {
    shaderEnv();
    await t.pumpWidget(page());
    GlassScrollEdge edge() => t.widget<GlassScrollEdge>(find.byType(GlassScrollEdge));
    expect(edge().visible, isFalse);
    await t.drag(find.byType(ListView), const Offset(0, -200));
    await t.pumpAndSettle();
    expect(edge().visible, isTrue);
  }, variant: ios);

  testWidgets('no back button on the root route', (t) async {
    shaderEnv();
    await t.pumpWidget(page());
    expect(find.byType(GlassBackButton), findsNothing);
  }, variant: ios);

  testWidgets('a pushed route gets a back button that pops', (t) async {
    shaderEnv();
    await t.pumpWidget(MaterialApp(home: Builder(builder: (c) => TextButton(
      onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(appBar: GlassNavigationBar(title: Text('Detail'))),
      )),
      child: const Text('open'),
    ))));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byType(GlassBackButton), findsOneWidget);
    await t.tap(find.byType(GlassBackButton));
    await t.pumpAndSettle();
    expect(find.text('Detail'), findsNothing);
  }, variant: ios);
}
```

- [ ] **Step 7: Run, verify failure**

Run: `flutter test test/navigation/glass_navigation_bar_test.dart`
Expected: compile errors.

- [ ] **Step 8: Implement scroll edge, content and bar**

`lib/src/navigation/scroll_edge.dart`:

```dart
import 'package:flutter/cupertino.dart';

/// iOS 26's scroll edge effect: the page background fading out below the
/// top edge, shown while content is under the bar.
class GlassScrollEdge extends StatelessWidget {
  const GlassScrollEdge({super.key, required this.visible, required this.height});

  final bool visible;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
      CupertinoTheme.of(context).scaffoldBackgroundColor, context);
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: SizedBox(
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [bg, bg.withValues(alpha: 0.85), bg.withValues(alpha: 0)],
              stops: const [0, 0.6, 1],
            )),
          ),
        ),
      ),
    );
  }
}
```

`lib/src/navigation/nav_bar_content.dart`:

```dart
import 'package:flutter/cupertino.dart';

import '../button/glass_button.dart';
import '../core/glass_render_mode.dart';
import '../group/glass_group.dart';
import '../group/glass_union_scope.dart';
import 'glass_back_button.dart';
import 'nav_bar_metrics.dart';

/// The bar row shared by both navigation bars: leading, centred title,
/// trailing actions merged into one glass capsule.
class NavBarContent extends StatelessWidget {
  const NavBarContent({
    super.key,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.title,
    this.titleOpacity = 1,
    this.actions = const [],
    this.mode,
  });

  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Widget? title;
  final double titleOpacity;
  final List<Widget> actions;
  final GlassRenderMode? mode;

  static const Object _actionsUnion = Object();

  @override
  Widget build(BuildContext context) {
    final lead = leading ??
        (automaticallyImplyLeading && glassCanImplyBack(context)
            ? GlassBackButton(mode: mode)
            : null);
    final label = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    return GlassControlSizeScope(
      size: NavBarMetrics.buttonControlSize,
      child: SizedBox(
        height: NavBarMetrics.barHeight,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: NavBarMetrics.edgeInset),
          child: NavigationToolbar(
            leading: lead,
            middle: title == null
                ? null
                : Opacity(
                    opacity: titleOpacity,
                    child: Semantics(
                      header: true,
                      child: DefaultTextStyle(
                        style: TextStyle(
                          fontSize: NavBarMetrics.titleFontSize,
                          fontWeight: FontWeight.w600,
                          color: label,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        child: title!,
                      ),
                    ),
                  ),
            trailing: actions.isEmpty
                ? null
                : GlassGroup(
                    mode: mode,
                    child: GlassUnionScope(
                      id: _actionsUnion,
                      child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                    ),
                  ),
            middleSpacing: 8,
          ),
        ),
      ),
    );
  }
}
```

`lib/src/navigation/glass_navigation_bar.dart`:

```dart
import 'package:flutter/material.dart';

import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/render_mode_resolver.dart';
import 'nav_bar_content.dart';
import 'nav_bar_metrics.dart';
import 'scroll_edge.dart';

/// iOS 26's navigation bar with an inline title: no bar background, a
/// glass back button, a centred title and trailing actions merged into
/// one glass capsule. Use as `Scaffold.appBar` with
/// `extendBodyBehindAppBar: true`. An [AppBar] on the Material path.
class GlassNavigationBar extends StatefulWidget implements PreferredSizeWidget {
  const GlassNavigationBar({
    super.key,
    this.title,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.actions = const [],
    this.mode,
  });

  final Widget? title;

  /// Defaults to a [GlassBackButton] when the route can pop.
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final List<Widget> actions;
  final GlassRenderMode? mode;

  @override
  Size get preferredSize => const Size.fromHeight(NavBarMetrics.barHeight);

  @override
  State<GlassNavigationBar> createState() => _GlassNavigationBarState();
}

class _GlassNavigationBarState extends State<GlassNavigationBar> {
  ScrollNotificationObserverState? _observer;
  bool _scrolledUnder = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _observer?.removeListener(_onScroll);
    _observer = ScrollNotificationObserver.maybeOf(context);
    _observer?.addListener(_onScroll);
  }

  @override
  void dispose() {
    _observer?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll(ScrollNotification n) {
    if (n is! ScrollUpdateNotification || n.depth != 0) return;
    if (n.metrics.axis != Axis.vertical) return;
    final under = n.metrics.extentBefore > 0;
    if (under != _scrolledUnder) setState(() => _scrolledUnder = under);
  }

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: widget.mode,
    builder: (context, effective) {
      if (effective == EffectiveGlassMode.material) {
        return AppBar(
          title: widget.title,
          leading: widget.leading,
          automaticallyImplyLeading: widget.automaticallyImplyLeading,
          actions: widget.actions,
        );
      }
      final top = MediaQuery.paddingOf(context).top;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0, right: 0, top: 0,
            child: GlassScrollEdge(
              visible: _scrolledUnder,
              height: top + NavBarMetrics.barHeight + 16,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: top),
            child: NavBarContent(
              leading: widget.leading,
              automaticallyImplyLeading: widget.automaticallyImplyLeading,
              title: widget.title,
              actions: widget.actions,
              mode: widget.mode,
            ),
          ),
        ],
      );
    },
  );
}
```

Exports in `lib/adaptive_liquid_glass.dart`:

```dart
export 'src/navigation/glass_navigation_bar.dart';
```

- [ ] **Step 9: Run tests**

Run: `flutter test test/navigation test/api`
Expected: PASS. If 'height is the measured bar…' fails because `Scaffold` lays out the bar at `preferredSize + top padding`, that's expected Material behaviour; keep the assertion on `preferredSize` only.

- [ ] **Step 10: Commit**

```bash
git add lib/src/group/glass_union_scope.dart lib/src/liquid_glass.dart lib/src/navigation lib/adaptive_liquid_glass.dart test/navigation test/api/union_scope_test.dart
git commit -m "feat: GlassNavigationBar with grouped glass actions and scroll edge"
```

---

### Task 7: GlassNavigationBar on the Material path

**Files:**
- Test: `test/navigation/glass_navigation_bar_material_test.dart`
- Modify: `lib/src/navigation/glass_navigation_bar.dart` (only if tests fail)

**Interfaces:**
- Consumes: `GlassNavigationBar` (Task 6) Material branch.

- [ ] **Step 1: Write tests**

`test/navigation/glass_navigation_bar_material_test.dart`:

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

void main() {
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('an M3 AppBar with the title and actions, no glass', (t) async {
    shaderEnv();
    await t.pumpWidget(MaterialApp(home: Scaffold(
      appBar: GlassNavigationBar(
        title: const Text('Inbox'),
        actions: [GlassButton.icon(onPressed: () {}, icon: CupertinoIcons.pencil)],
      ),
    )));
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.byType(IconButton), findsOneWidget);
    expect(find.byType(LiquidGlass), findsNothing);
  }, variant: android);

  testWidgets('pushed route shows the Material back button', (t) async {
    shaderEnv();
    await t.pumpWidget(MaterialApp(home: Builder(builder: (c) => TextButton(
      onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(appBar: GlassNavigationBar(title: Text('Detail'))),
      )),
      child: const Text('open'),
    ))));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
  }, variant: android);
}
```

Note: the action is a `GlassButton.icon` → on Android it renders `IconButton.filledTonal`; the test accepts any `IconButton`.

- [ ] **Step 2: Run**

Run: `flutter test test/navigation/glass_navigation_bar_material_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add test/navigation/glass_navigation_bar_material_test.dart
git commit -m "test: GlassNavigationBar Material path"
```

---

### Task 8: SliverGlassNavigationBar (large title, collapse, stretch)

**Files:**
- Create: `lib/src/navigation/sliver_glass_navigation_bar.dart`
- Modify: `lib/adaptive_liquid_glass.dart`
- Test: `test/navigation/sliver_glass_navigation_bar_test.dart`

**Interfaces:**
- Consumes: `NavBarContent`, `NavBarMetrics`, `GlassScrollEdge`, `GlassModeBuilder`.
- Produces: `SliverGlassNavigationBar({Key?, required Widget largeTitle, Widget? title, Widget? leading, bool automaticallyImplyLeading = true, List<Widget> actions = const [], GlassRenderMode? mode})`; `double inlineTitleOpacity(double shrinkOffset)` (top-level, for tests).

- [ ] **Step 1: Write failing tests**

`test/navigation/sliver_glass_navigation_bar_test.dart`:

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/navigation/nav_bar_metrics.dart';
import 'package:adaptive_liquid_glass/src/navigation/scroll_edge.dart';
import 'package:adaptive_liquid_glass/src/navigation/sliver_glass_navigation_bar.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

final controller = ScrollController();

Widget page({TextDirection dir = TextDirection.ltr, double textScale = 1}) => MaterialApp(
  builder: (c, child) => MediaQuery.withClampedTextScaling(
    minScaleFactor: textScale, maxScaleFactor: textScale,
    child: Directionality(textDirection: dir, child: child!),
  ),
  home: Scaffold(body: CustomScrollView(
    controller: controller,
    physics: const BouncingScrollPhysics(),
    slivers: [
      const SliverGlassNavigationBar(largeTitle: Text('Inbox')),
      SliverList.builder(
        itemCount: 60,
        itemBuilder: (_, i) => SizedBox(height: 44, child: Text('Row $i')),
      ),
    ],
  )),
);

double inlineOpacity(WidgetTester t) => t
    .widget<Opacity>(find.ancestor(of: find.text('Inbox').first, matching: find.byType(Opacity)).first)
    .opacity;

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  test('inline title fades over the measured range', () {
    expect(inlineTitleOpacity(NavBarMetrics.inlineFadeStart), 0);
    expect(inlineTitleOpacity(NavBarMetrics.inlineFadeEnd), 1);
    expect(inlineTitleOpacity((NavBarMetrics.inlineFadeStart + NavBarMetrics.inlineFadeEnd) / 2),
        moreOrLessEquals(0.5, epsilon: 0.01));
  });

  testWidgets('at rest: large title at the start below the bar; inline hidden', (t) async {
    shaderEnv();
    await t.pumpWidget(page());
    final titles = find.text('Inbox');
    expect(titles, findsNWidgets(2)); // inline + large
    final large = t.getRect(titles.last);
    expect(large.left, moreOrLessEquals(NavBarMetrics.largeTitleInset, epsilon: 1));
    expect(DefaultTextStyle.of(t.element(titles.last)).style.fontSize,
        NavBarMetrics.largeTitleFontSize);
    expect(t.widget<GlassScrollEdge>(find.byType(GlassScrollEdge)).visible, isFalse);
  }, variant: ios);

  testWidgets('scrolling collapses: inline title fades in, edge shows', (t) async {
    shaderEnv();
    await t.pumpWidget(page());
    controller.jumpTo(NavBarMetrics.largeTitleHeight + 20);
    await t.pump();
    expect(t.widget<GlassScrollEdge>(find.byType(GlassScrollEdge)).visible, isTrue);
    expect(find.text('Inbox'), findsWidgets);
  }, variant: ios);

  testWidgets('pulling down stretches the large title', (t) async {
    shaderEnv();
    await t.pumpWidget(page());
    final before = t.getSize(find.text('Inbox').last);
    final g = await t.startGesture(t.getCenter(find.text('Row 5')));
    await g.moveBy(const Offset(0, 120));
    await t.pump();
    final transform = t.widget<Transform>(find.ancestor(
      of: find.text('Inbox').last, matching: find.byType(Transform)).first);
    expect(transform.transform.getMaxScaleOnAxis(), greaterThan(1));
    await g.up();
    await t.pumpAndSettle();
    expect(t.getSize(find.text('Inbox').last), before);
  }, variant: ios);

  testWidgets('RTL: large title at the right', (t) async {
    shaderEnv();
    await t.pumpWidget(page(dir: TextDirection.rtl));
    expect(800 - t.getRect(find.text('Inbox').last).right,
        moreOrLessEquals(NavBarMetrics.largeTitleInset, epsilon: 1));
  }, variant: ios);

  testWidgets('large text: no overflow', (t) async {
    shaderEnv();
    await t.pumpWidget(page(textScale: 2));
    expect(t.takeException(), isNull);
  }, variant: ios);

  testWidgets('Material: SliverAppBar.large', (t) async {
    shaderEnv();
    await t.pumpWidget(page());
    expect(find.byType(SliverAppBar), findsOneWidget);
  }, variant: android);
}
```

- [ ] **Step 2: Run, verify failure**

Run: `flutter test test/navigation/sliver_glass_navigation_bar_test.dart`
Expected: compile error.

- [ ] **Step 3: Implement**

`lib/src/navigation/sliver_glass_navigation_bar.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SliverAppBar;

import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/render_mode_resolver.dart';
import 'nav_bar_content.dart';
import 'nav_bar_metrics.dart';
import 'scroll_edge.dart';

/// Inline title opacity at [shrinkOffset] (measured fade range).
double inlineTitleOpacity(double shrinkOffset) => ((shrinkOffset -
            NavBarMetrics.inlineFadeStart) /
        (NavBarMetrics.inlineFadeEnd - NavBarMetrics.inlineFadeStart))
    .clamp(0.0, 1.0);

/// iOS 26's large-title navigation bar for a `CustomScrollView`: the large
/// title scrolls up under the bar, the inline title fades in, pulling down
/// stretches the large title. `SliverAppBar.large` on the Material path.
class SliverGlassNavigationBar extends StatelessWidget {
  const SliverGlassNavigationBar({
    super.key,
    required this.largeTitle,
    this.title,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.actions = const [],
    this.mode,
  });

  final Widget largeTitle;

  /// The inline title; defaults to [largeTitle].
  final Widget? title;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final List<Widget> actions;
  final GlassRenderMode? mode;

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) {
      if (effective == EffectiveGlassMode.material) {
        return SliverAppBar.large(
          title: title ?? largeTitle,
          leading: leading,
          automaticallyImplyLeading: automaticallyImplyLeading,
          actions: actions,
        );
      }
      final scale = MediaQuery.textScalerOf(context)
              .scale(NavBarMetrics.largeTitleFontSize) /
          NavBarMetrics.largeTitleFontSize;
      return SliverPersistentHeader(
        pinned: true,
        delegate: _LargeTitleDelegate(
          bar: this,
          top: MediaQuery.paddingOf(context).top,
          largeTitleHeight: NavBarMetrics.largeTitleHeight * scale,
        ),
      );
    },
  );
}

class _LargeTitleDelegate extends SliverPersistentHeaderDelegate {
  _LargeTitleDelegate({required this.bar, required this.top, required this.largeTitleHeight});

  final SliverGlassNavigationBar bar;
  final double top;
  final double largeTitleHeight;

  @override
  double get minExtent => top + NavBarMetrics.barHeight;

  @override
  double get maxExtent => minExtent + largeTitleHeight;

  @override
  OverScrollHeaderStretchConfiguration get stretchConfiguration =>
      OverScrollHeaderStretchConfiguration();

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final label = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    return LayoutBuilder(builder: (context, constraints) {
      final stretch = math.max(0.0, constraints.maxHeight - maxExtent);
      // iOS grows the large title up to ~12 % from its leading edge.
      final grow = 1 + math.min(stretch / 400, 0.12);
      return Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0, right: 0, top: 0,
            child: GlassScrollEdge(
              visible: shrinkOffset > 0 || overlapsContent,
              height: minExtent + 16,
            ),
          ),
          // Large title, clipped under the bar as it scrolls away.
          Positioned(
            left: 0, right: 0, top: minExtent, bottom: 0,
            child: ClipRect(
              child: OverflowBox(
                alignment: AlignmentDirectional.bottomStart,
                maxHeight: largeTitleHeight + stretch,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: NavBarMetrics.largeTitleInset,
                    end: NavBarMetrics.largeTitleInset,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.bottomStart,
                    child: Transform.scale(
                      scale: grow,
                      alignment: AlignmentDirectional.bottomStart.resolve(
                        Directionality.of(context)),
                      child: Semantics(
                        header: true,
                        child: DefaultTextStyle(
                          style: TextStyle(
                            fontSize: NavBarMetrics.largeTitleFontSize,
                            fontWeight: FontWeight.bold,
                            color: label,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          child: bar.largeTitle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0, right: 0, top: top,
            child: NavBarContent(
              leading: bar.leading,
              automaticallyImplyLeading: bar.automaticallyImplyLeading,
              title: ExcludeSemantics(
                excluding: inlineTitleOpacity(shrinkOffset) == 0,
                child: bar.title ?? bar.largeTitle,
              ),
              titleOpacity: inlineTitleOpacity(shrinkOffset),
              actions: bar.actions,
              mode: bar.mode,
            ),
          ),
        ],
      );
    });
  }

  @override
  bool shouldRebuild(_LargeTitleDelegate old) =>
      old.bar != bar || old.top != top || old.largeTitleHeight != largeTitleHeight;
}
```

Export in `lib/adaptive_liquid_glass.dart`:

```dart
export 'src/navigation/sliver_glass_navigation_bar.dart' show SliverGlassNavigationBar;
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/navigation`
Expected: PASS. If the at-rest test finds the inline and large titles in a different order, select the large one with `find.byWidgetPredicate((w) => w is DefaultTextStyle && w.style.fontSize == NavBarMetrics.largeTitleFontSize)` as the ancestor and re-run.

- [ ] **Step 5: Commit**

```bash
git add lib/src/navigation/sliver_glass_navigation_bar.dart lib/adaptive_liquid_glass.dart test/navigation/sliver_glass_navigation_bar_test.dart
git commit -m "feat: SliverGlassNavigationBar — large title collapse and stretch"
```

---

### Task 9: Gallery, docs, and simulator check against SwiftUI

**Files:**
- Modify: `example/lib/gallery.dart` (two recipes)
- Create: `example/lib/navbar_probe.dart` (Flutter twin of `NavBarReference`)
- Modify: `README.md`, `CHANGELOG.md`
- Test: `example/test/gallery_test.dart` (existing smoke test must still pass)

**Interfaces:**
- Consumes: every public type above.

- [ ] **Step 1: Gallery recipes**

Add to the `ListView` children in `example/lib/gallery.dart`:

```dart
                _Recipe('Buttons (GlassButton)', _Buttons()),
                _Recipe('Navigation bar', _NavBarDemo()),
```

and the widgets:

```dart
class _Buttons extends StatelessWidget {
  const _Buttons();

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      for (final size in GlassControlSize.values)
        GlassButton(onPressed: () {}, size: size, child: Text(size.name)),
      GlassButton(
        onPressed: () {},
        style: GlassButtonStyle.glassProminent,
        child: const Text('Prominent'),
      ),
      GlassButton(
        onPressed: () {},
        role: GlassButtonRole.destructive,
        child: const Text('Delete'),
      ),
      const GlassButton(onPressed: null, child: Text('Disabled')),
      GlassButton(onPressed: () {}, loading: true, child: const Text('Saving')),
      GlassButton.icon(
        onPressed: () {},
        icon: CupertinoIcons.share,
        semanticLabel: 'Share',
      ),
    ],
  );
}

class _NavBarDemo extends StatelessWidget {
  const _NavBarDemo();

  @override
  Widget build(BuildContext context) => GlassButton(
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverGlassNavigationBar(
                largeTitle: const Text('Inbox'),
                actions: [
                  GlassButton.icon(
                    onPressed: () {},
                    icon: CupertinoIcons.square_pencil,
                    semanticLabel: 'Compose',
                  ),
                  GlassButton.icon(
                    onPressed: () {},
                    icon: CupertinoIcons.ellipsis,
                    semanticLabel: 'More',
                  ),
                ],
              ),
              SliverList.builder(
                itemCount: 60,
                itemBuilder: (_, i) => SizedBox(
                  height: 44,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text('Row $i'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    child: const Text('Open a large-title page'),
  );
}
```

Run: `cd example && flutter analyze && flutter test` → PASS.

- [ ] **Step 2: Flutter twin of the SwiftUI nav screen**

`example/lib/navbar_probe.dart`:

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The `-controls navbar` SwiftUI screen in Flutter, scrolled to
/// `--dart-define=SCROLL_Y=<pt>`, for side-by-side comparison:
/// `flutter run -t lib/navbar_probe.dart --dart-define=SCROLL_Y=40`.
void main() {
  const y = double.fromEnvironment('SCROLL_Y');
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(scaffoldBackgroundColor: Colors.white),
    home: Scaffold(
      body: CustomScrollView(
        controller: ScrollController(initialScrollOffset: y),
        slivers: [
          SliverGlassNavigationBar(
            largeTitle: const Text('Inbox'),
            actions: [
              GlassButton.icon(onPressed: () {}, icon: CupertinoIcons.square_pencil),
              GlassButton.icon(onPressed: () {}, icon: CupertinoIcons.ellipsis),
            ],
          ),
          SliverList.builder(
            itemCount: 60,
            itemBuilder: (_, i) => SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
                child: Align(alignment: AlignmentDirectional.centerStart, child: Text('Row $i')),
              ),
            ),
          ),
        ],
      ),
    ),
  ));
}
```

- [ ] **Step 3: Compare on the simulator**

For `y` in `0 40 100`: run `flutter run -d 2AC3AF21-6F97-4706-AE23-3F507BE9699F -t lib/navbar_probe.dart --dart-define=SCROLL_Y=$y`, screenshot with `xcrun simctl io <UDID> screenshot build/reference/flutter_navbar_$y.png`, and put each next to `build/reference/navbar_$y.png`. Check: bar height, back/action positions, large-title position and inline-title opacity agree within 1 pt / 0.1. Fix `NavBarMetrics` (and its test JSON if the reference was mis-measured) for any mismatch, then re-run `flutter test`.

Then record one live scroll in both (same `touch_path` flick from y=700 to y=300 over 300 ms) with `xcrun simctl io <UDID> recordVideo`, and compare large-title collapse frame by frame as done for the tab bar (scripts in the session scratchpad: lens tracker pattern, replace the strip with the large-title bbox). Note any timing difference in the PR/commit message.

- [ ] **Step 4: Docs**

`README.md` — add after the Tab bar recipe:

````markdown
### Buttons

`GlassButton` is SwiftUI's `.buttonStyle(.glass)` / `.glassProminent`,
with roles, control sizes, border shapes, and disabled and loading states:

```dart
GlassButton(onPressed: save, child: const Text('Save'))
GlassButton(
  onPressed: delete,
  role: GlassButtonRole.destructive,
  style: GlassButtonStyle.glassProminent,
  child: const Text('Delete'),
)
GlassButton.icon(onPressed: share, icon: CupertinoIcons.share, semanticLabel: 'Share')
```

On Android it is a Material 3 `FilledButton` (`.tonal` for `glass`),
`IconButton` for icon-only buttons, `TextButton` for `cancel`.

### Navigation bar

```dart
Scaffold(
  extendBodyBehindAppBar: true,
  appBar: GlassNavigationBar(title: const Text('Detail'), actions: [...]),
  body: ...,
)

CustomScrollView(slivers: [
  SliverGlassNavigationBar(largeTitle: const Text('Inbox'), actions: [...]),
  SliverList(...),
])
```

No bar background, as on iOS 26: a glass back button when the route can
pop, the actions merged into one glass capsule, and a scroll edge fade
once content is under the bar. The large title collapses into the inline
title as you scroll and stretches when you pull down. On Android these are
`AppBar` and `SliverAppBar.large`.
````

`CHANGELOG.md` — new top section:

```markdown
## 0.1.0-dev.4

* `GlassButton` / `GlassButton.icon`: SwiftUI's glass and prominent
  button styles, destructive and cancel roles, five control sizes, border
  shapes, disabled and loading states; Material 3 buttons on Android.
  Sizes measured from SwiftUI (`tool/reference/controls.json`).
* `GlassBackButton`, `GlassNavigationBar` (inline) and
  `SliverGlassNavigationBar` (collapsing large title): iOS 26's navigation
  bar; `AppBar` / `SliverAppBar.large` on Android.
```

Bump `pubspec.yaml` `version: 0.1.0-dev.4`.

- [ ] **Step 5: Full verification and commit**

Run: `flutter analyze && flutter test && (cd example && flutter analyze && flutter test)`
Expected: no issues; all tests pass.

```bash
git add example/lib/gallery.dart example/lib/navbar_probe.dart README.md CHANGELOG.md pubspec.yaml example/pubspec.lock
git commit -m "docs: Phase 2a gallery, probe, README and changelog (0.1.0-dev.4)"
```

---

### Task 10: Side-by-side re-check of both bars against native iOS

User request (2026-10-05): after this plan, compare the tab bar and the
navigation bar against native iOS once more and fix what differs.

**Files:**
- Modify (only for mismatches found): `lib/src/tab_bar/glass_tab_bar.dart`, `lib/src/navigation/nav_bar_metrics.dart`, `lib/src/navigation/sliver_glass_navigation_bar.dart`
- Create: `tool/reference/compare_bars.md` (results table)

- [ ] **Step 1: Tab bar vs Kept (iOS 26.4)**

Run `example/lib/tab_bar_probe.dart` and Kept (`com.approots.Kept`) on
`2AC3AF21-6F97-4706-AE23-3F507BE9699F`; record with `xcrun simctl io <UDID>
recordVideo` the same three `touch_path` gestures in both: (a) tap
another tab, (b) press-hold 0.7 s then drag 172 pt left over 0.7 s, (c)
slow drag 90 pt right then a fast flick to the far end. Extract 60 fps
frames (`ffmpeg -vf "fps=60,crop=1206:400:0:2222"`), track lens centre,
height and width per frame, align on drag start, and build a side-by-side
contact sheet for each gesture.

- [ ] **Step 2: Navigation bar vs SwiftUI**

Use `-controls navbar` (Task 1) and `example/lib/navbar_probe.dart`
(Task 9): static offsets 0/20/40/60/100 side by side, plus one recorded
flick in each, tracking large-title top, scale and inline-title opacity.

- [ ] **Step 3: Fix and record**

For every difference over 1 pt / 1 frame / 0.1 opacity, fix the
constant or code, re-run the comparison, and write the before/after table
to `tool/reference/compare_bars.md`. Run `flutter test`.

- [ ] **Step 4: Commit**

```bash
git add tool/reference/compare_bars.md lib/src
git commit -m "fix: tab and navigation bars re-matched against native iOS"
```

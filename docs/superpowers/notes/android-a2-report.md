# A2 report — Android example app and audit tests on the U1 API

Worktree `/Users/aymanomara/Android Studio Projects/alg-android-audit`, branch
`android-audit`. Follows A1 (`docs/superpowers/notes/android-audit-report.md`) after the usability
task U1 changed the public API.

## 1. Merge result

- `git merge --no-edit worktree-agent-a27d97b1b4d271796` → **clean merge,
  no conflicts** (merge commit `cf95d58`).
- Why it was clean: since the merge base (`1ccf0c5`) the `android-audit`
  branch had only *added* files (`ANDROID_AUDIT_REPORT.md`,
  `test/android_material_path_test.dart`); U1 changed `lib/`, `pubspec.yaml`,
  `README.md`, `CHANGELOG.md`, `example/lib/`, `example/test/` — no overlap.
- U1 brought in: `glassEffect()`, `padding`/`onPressed`/`adaptiveForeground`
  on `LiquidGlass`, the Dart-only Android plugin declaration
  (`lib/src/platform/adaptive_liquid_glass_android.dart`), lazy shader loading (A1 4.3 fix),
  the real Material `onPressed` path (A1 4.6 fix), the example Gallery page
  and the `test/api/` suite. 35 files, +2633/−565.

## 2. Tests

### 2.1 Updated `test/android_material_path_test.dart`

The two tests that documented the A1 findings now assert the fixed
behaviour, and the required new Material-path coverage was added:

| Test | Asserts |
| --- | --- |
| `the shader program is never loaded on the Material path` | (A1 4.3 fix) with a *real* load armed (`debugReset()`), pumping Material glass reports no error and `GlassProgram.instance.program.value` stays `null` — no asset read, no SL compile |
| `onPressed fires on the Material path` | (A1 4.6 fix) `tap('Go')` calls the callback; a tap inside the capsule's padding cap calls it too; no glass code path runs |
| `button semantics follow onPressed` | with `onPressed`: `isButton`, `hasTapAction`, `isFocusable`, `isEnabled`, label `'Go'`; without it: not a button |
| `Text('x').glassEffect()` | renders one `MaterialGlass` (capsule → `StadiumBorder`, `surfaceContainerHigh`), text present, no glass path |
| `padding insets the child inside the Material surface` | `EdgeInsetsDirectional.only(start:16, end:4, top:8, bottom:2)` grows the glass to 60×30 and offsets the child (16, 8) |
| `the adaptive foreground labels with onSurface` | `DefaultTextStyle`/`IconTheme` inside the glass = `colorScheme.onSurface` |
| `tinted glass labels with onPrimaryContainer` | `Glass.regular.tint(orange)` → labels = seeded `onPrimaryContainer` |

Also updated for the new always-present ink-well structure
(`MaterialGlass.pressable`, `lib/src/material/material_glass.dart:90-114`):
the plain-surface test now asserts the inert well (`onTap: null`,
`canRequestFocus: false`, `excludeFromSemantics: true`) instead of "no
InkWell", and the interactive-ripple test additionally asserts the enabling
no-op `onTap`. One import fix: `GlassMemberBox`/`RenderGlassMember` moved to
`src/group/glass_member.dart` in U1.

### 2.2 Results (all green)

| Command | Result |
| --- | --- |
| `flutter test` (package) | **172 passed, 0 failed** (21 of them in `android_material_path_test.dart`, all on the android variant) |
| `flutter test` (example) | 1 passed (`gallery_test.dart`) |
| `flutter analyze` | No issues found |
| `dart format test/android_material_path_test.dart` | 0 changes needed |

## 3. Example on Android

`flutter create --platforms=android --org com.aymanomara
--project-name adaptive_liquid_glass_example .` wrote `example/android/`
(application id `com.aymanomara.adaptive_liquid_glass_example`,
`MainActivity` in Kotlin, Gradle Kotlin-DSL) and `example/.metadata`.
`example/lib/`, `example/ios/` and `example/pubspec.yaml` are untouched.
Two other files changed as consequences of the platform add and were kept
(and committed): `example/analysis_options.yaml` (+ `android/**` analyzer
exclude, added by `flutter create` itself) and `example/pubspec.lock`
(re-resolve: `meta` 1.19.0 → 1.18.3, `vector_math` 2.4.3 → 2.4.0).
The stray generated `example/test/widget_test.dart` was deleted per the
task rules. `local.properties`/`*.iml`/`.gradle` are excluded by the
generated `example/android/.gitignore`.

**`launch.dart` fallback on Android — verified, no fix needed.**
`LaunchArgs.read()` (`example/lib/launch.dart:31-45`) invokes the
`example/launch` method channel, which no Android handler answers, so it
throws `MissingPluginException` — which `read()` catches, returning all-null
args. On-device the app started straight into the normal Demo (+ Gallery
page) with no Dart error in logcat. `LiquidGlass.precache()` in `main()`
also stays harmless: the A1 4.3 fix means the group no longer loads the
shader, and `precache` itself only loads (and fails silently to a usable
Material path) if called — on Android it resolves immediately since
`load()` is only invoked on the backdrop path (`lib/src/group/glass_group.dart:327-330`).
No edit to `example/lib/` was required.

## 4. Build and run

### 4.1 Build

`flutter build apk --debug` in `example/` → **success**
(`build/app/outputs/flutter-apk/app-debug.apk`, Gradle `assembleDebug`
58.8 s). Running on the Impeller (OpenGLES) backend.

**The impellerc SkSL warning appeared**, as predicted:

```
warning: Shader `.../shaders/liquid_glass.frag` is incompatible with SkSL.
impellerc failure: Compilation failed for target: SkSL
SkSL Error: error: 35: index expression must be constant
        vec4 rc = uRects[i];
```

Known issue owned by another session (a fix is coming); build-time only,
the APK builds and the Material path never touches the shader at runtime.

### 4.2 Emulator run (Pixel_8_Pro)

Install → launch → Demo; tapped the glass "Gallery" capsule (this itself is
a `LiquidGlass.onPressed`, proving the Material-path button on-device),
browsed the Gallery, tapped the "Continue" recipe button → SnackBar
"Pressed" appeared (runtime `onPressed` + snack confirmation). Switched
`cmd uimode night yes|no`; system dark mode took effect (status-bar icons
black → white), the app content stayed light — see §5.2. Logcat for the app
process: **no errors, no Flutter exceptions, no `MissingPluginException`
crash, no shader runtime error** (the only line matching is a benign
emulator `HWUI: Failed to initialize 101010-2 format` from system UI).
Emulator shut down afterwards.

### 4.3 Screenshots (worktree root; not committed)

| File | Shows |
| --- | --- |
| `android-a2-demo-light.png` | Demo, light system theme. The six-stop diagonal gradient (blue→purple→pink→amber→green→sky) with the 30 translucent white stripes; central rounded-rect (r=28) Material glass card, `surfaceContainerHigh`, black "Liquid Glass" label; top-right "Gallery" capsule; bottom `GlassGroup` row of three capsule Materials over the green band |
| `android-a2-gallery-light.png` | Gallery page, light: photo backdrop (teal/green), transparent AppBar, six cookbook recipes as Material glass surfaces — Continue button, padded card, morphing-pair circles, merged-union icon trio, clear-glass-over-media player, tinted capsule |
| `android-a2-demo-dark.png` | Same Demo with system dark mode on: status-bar icons flip to white; glass content unchanged (example is fixed-light, §5.2) |
| `android-a2-gallery-dark.png` | Same Gallery with system dark mode on; status-bar icons white, content unchanged |

(Verification note: Flutter text is not exposed to `uiautomator` without an
accessibility service, so the screenshots were validated structurally —
sampled colours match the coded gradient/stripe/surface colours exactly,
and the light/dark pair differs exactly in the status-bar icon band.)

## 5. Problems

### 5.1 Warning (known, external) — shader is not SkSL-compatible

- **Where**: `shaders/liquid_glass.frag` (dynamic indexing `uRects[i]`
  rejected by SkSL during the debug-APK impellerc pass).
- **Impact**: build-time warning only on Android; the Material path never
  loads the shader at runtime. Owned by another session; fix incoming — no
  action here (and `shaders/` is off-limits for this task).

### 5.2 Info — the example is fixed-light; system dark mode only changes system UI

- **Where**: `example/lib/main.dart:52-54` — `MaterialApp` sets no
  `darkTheme:`/`themeMode:`, so `ThemeData` stays light whatever the
  platform brightness; the package itself theming is correct (the suite
  proves dark schemes drive the surfaces when a dark `ThemeData` is used).
- **Impact**: cosmetic; dark-mode screenshots differ only in the status-bar
  icons. Not fixed here (rule: don't edit `example/lib/`).
- **Proposed fix**:
  ```dart
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
    ),
    home: ...,
  )
  ```

### 5.3 Note — `flutter create` side effects, kept deliberately

`example/analysis_options.yaml` (+`android/**` exclude) and
`example/pubspec.lock` (minor downgrades from the local resolution) changed
with the platform add and are committed; both are generated/config
consequences of `example/android/`, no hand edits.

No other defects: launch fallback clean, no app-process logcat errors,
debug APK builds, all package + example tests pass, analyzer clean.

## 6. Commits

- `cf95d58` — merge U1 (`worktree-agent-a27d97b1b4d271796`) into
  `android-audit` (clean).
- `ef5a5ce8447c450238aa0d324572a6f566e4f50d` — test updates +
  `example/android/` + `.metadata` (+ the two §5.3 side files).
  Screenshots, `GLM_TASK*.md`, `opencode.json` and `glm-run*.log` left
  uncommitted. Not pushed.

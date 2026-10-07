# Shared brief for every workstream (feat/borrow-lgw)

Package: `adaptive_liquid_glass` (Flutter). iOS 26 Liquid Glass measured against
SwiftUI, with Material 3 counterparts on Android behind one API. Main checkout:
`~/Android Studio Projects/adaptive_liquid_glass` (branch `feat/borrow-lgw`).
You work in your own git worktree; commit there on your own branch. Do not push.
Never run `dart pub publish`.

Plan / what to borrow: `docs/superpowers/notes/borrow-from-liquid-glass-widgets.md`.
Source to borrow from (MIT): `dart pub unpack liquid_glass_widgets:1.10.0` into a scratch dir.
Borrow ideas and adapt to OUR architecture. If you copy a non-trivial block of
code verbatim or near-verbatim, keep a short provenance comment
(`// Adapted from liquid_glass_widgets (MIT, Sebastian Degenaar).`) and tell the
coordinator so `THIRD_PARTY_NOTICES` can be updated.

## Conventions (binding)
- One public class per file (a StatefulWidget and its State may share a file).
- No colour literals in widgets: colours are static constants on
  `GlassColors` (`lib/src/core/glass_colors.dart`) — add new ones in a section
  with a `// <Component>` comment so parallel branches merge cleanly.
- Geometry numbers live in a `<component>_metrics.dart` `abstract final class`
  (see `lib/src/search/search_metrics.dart`). Say in the doc comment whether a
  value is measured from SwiftUI or estimated. Never claim "measured" for a
  guess.
- Each component chooses its path with `GlassModeBuilder(mode:, builder: (ctx, effective) ...)`
  and has a Material 3 path when `effective == EffectiveGlassMode.material`
  (see `lib/src/stepper/glass_stepper.dart`, `lib/src/search/glass_search_field.dart`).
  Glass surfaces use `LiquidGlass` / `Glass.regular` like existing components.
- RTL-safe: `EdgeInsetsDirectional`, `AlignmentDirectional`, start/end.
- User-visible default strings come from `lib/src/core/cupertino_l10n.dart`
  patterns where possible; semantics labels overridable.
- Respect Reduce Motion (`MediaQuery.disableAnimationsOf`) and the
  high-contrast path the package already has.
- Public API: export new public files from `lib/adaptive_liquid_glass.dart`
  (append lines; keep alphabetical within reason). Dartdoc every public member
  with a short usage example on the class, like existing components.
- Match the surrounding code's comment density and naming.
- Tests: mirror `test/<area>/..._test.dart`; use `test/api/hosts.dart`
  (`plainHost`, `appHost`, `shaderEnv`, `ios`/`android` variants) and
  `setUp(() => GlassProgram.instance.debugReset(skipLoad: true))`,
  `tearDown(() => GlassPlatform.instance.debugReset())`. Cover iOS glass path
  AND Android Material path, semantics, RTL, disabled state.
- Before committing: `flutter analyze` (zero issues) and `flutter test` (all
  pass; baseline is 626 passing). Run `dart format` on changed files.
- Do NOT touch the reference simulator `E7A87B4A-3E48-44F8-A588-704D56774FF0`
  unless your brief says so (only the A1 stream uses it).
- Commit messages: conventional (`feat:`, `fix:`), ending with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Using GLM (requested by the user)
GLM runs through opencode (non-interactive):
```
command opencode run -m zai-coding-plan/glm-5.3 "<self-contained prompt>"
```
Run it from your worktree directory (it edits files there). Give GLM a
self-contained, precise prompt (paths, API shape, conventions above, tests to
write, commands to run). Use it for well-specified implementation work; YOU stay
responsible: read every file it changed (`git diff`), fix what is wrong, and
run analyze + tests yourself. If GLM fails or produces poor code twice on a
task, do the task yourself. Report which parts GLM wrote.

## Final report (keep it short)
Branch name, commit list, what was done per item, what GLM wrote, test/analyze
results, anything skipped and why, any verbatim-borrowed code.

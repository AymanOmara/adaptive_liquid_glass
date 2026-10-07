# Handoff (2026-10-07)

State of `feat/borrow-lgw` for whoever picks this up next (another account or session).

## Where things are
- Branch `feat/borrow-lgw` holds everything below. It is **not pushed and not merged to main**. 0.1.0-dev.7 is on pub.dev; work after it is unreleased.
- Next work: `TODO.md` (items 5-8) and `docs/superpowers/notes/tabbar-todo.md`.
- Brief for sub-agents/GLM: `docs/superpowers/notes/agent-brief.md` (conventions, test helpers, GLM usage).
- Tests: `flutter analyze` clean, 626 tests pass; `tool/fidelity` pytest 200 pass.

## Merged since dev.7
- Tab bar round 2 (badge, magnifier, shadow, quick-tap lens hold, pill/label/icon placement).
- New components: GlassDisclosureGroup, GlassEmptyState, showGlassFullScreenCover, GlassGauge.
- Fidelity groups 1+3 colour refit: device 47/75 → 55/75 (`build/fidelity/g13-2`).

## Tools and machine state
- Fidelity: `tool/fidelity/` (README there). The venv `tool/fidelity/.venv` and captures in `build/` exist only in the main checkout (not in git).
- Side by side vs SwiftUI: `tool/reference/side_by_side.sh`, `tool/reference/show_pair.sh`.
- Simulators (iPhone 17 Pro, iOS 26.4, light): `E7A87B4A-…` fidelity reference (only for fidelity runs), `2AC3AF21-…` components, `62E521E0-…` tab bar.
- GLM: `command opencode run -m zai-coding-plan/glm-5.3 "<prompt>"`, relative paths (the repo path has a space). Kill long fit jobs when done; a stale one once pushed the load average to ~990.
- `.claude/worktrees/` holds old agent worktrees; all their work is merged, so they can be cleaned up.

## Rules
- Never `dart pub publish` without an explicit request from the user; dry-run is fine.
- No push, PR or merge to main without the user.
- Commits end with a `Co-Authored-By:` line.

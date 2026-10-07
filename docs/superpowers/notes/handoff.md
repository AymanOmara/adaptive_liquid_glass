# Handoff (2026-10-08)

All of the 2026-10-07 list is merged on `feat/borrow-lgw` (not pushed, not published):
dev.8 metadata (dry-run clean), worktree cleanup, refactor (one class per file, colours
as `GlassColors` constants), empty-state/button-label fixes, full-screen cover
drag-to-dismiss + close button, tab bar round 3 (TODO item 5 Medium), fidelity group 4
(55→58/75, `build/fidelity/g4-1`), plus GlassWheelPicker/GlassActivityIndicator/presets
from a parallel session. analyze clean, 679 tests.

## Next
1. Fidelity item 8 (regular photo scenes): ΔE blocker looks backdrop-dependent; see
   fidelity-status.md group-4 notes. Needs a new model term, not a refit.
2. Tab bar: shader-mode photo scene 5.14 (was 4.77), the "Hard" list in TODO item 5.
3. Component gap "Next (medium)" in TODO item 7, then the usability pass
   (memory: usability-pass-after-fidelity).
4. Optional: rename 8 files whose name ≠ class (see refactor report in git log 699c4ab..6bd738c).
5. Publish only when the user asks.

Rules unchanged: no push/PR/merge to main or `dart pub publish` without the user;
reference sim E7A87B4A only for fidelity; commits end with `Co-Authored-By:`.

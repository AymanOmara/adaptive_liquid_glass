# Handoff (2026-10-07, evening — work paused by the user)

Resume by reading this file, then TODO.md.

## Branch map (nothing pushed, nothing published)
- `feat/borrow-lgw` (main checkout): dev.7 history + `0257ea1` dev.8 metadata/screenshots
  (dry-run clean, NOT published) + `47441d5` **wip(fidelity)**: an unverified edge-lens
  experiment in `shaders/liquid_glass.frag` and `tool/fidelity/glass_model.py`. Verify or
  revert that commit before any fidelity run (`git revert 47441d5` restores g13-2 state).
- `feat/wt-integrate` (worktree `.claude/worktrees/integrate`): feat/borrow-lgw@0257ea1
  + Android A2 report + the **finished refactor** (one class per file, 17 colour constants,
  analyze clean, 626/626). → Merge into feat/borrow-lgw first.
- `feat/comp-followups` (worktree `.claude/worktrees/comp-followups`), from wt-integrate:
  `9fddac9` empty-state placement fix, `4d2c4f7` button label black (both done) +
  `5fdf5a7` **wip** full-screen cover drag-to-dismiss + close button (unfinished).
- `feat/tabbar-medium` (worktree `.claude/worktrees/tabbar-medium`), from wt-integrate:
  `5694a69` **wip** label-flip investigation (unfinished, no fix yet).
- `worktree-agent-a687ba16535ca1839`: the refactor source branch, already merged into
  wt-integrate; its worktree can be removed.
- `../alg-android-audit`, `../alg-glm-task9`: merged; keep only untracked screenshots/GLM scratch.

## Next steps (user's chosen list: 1,2,3,4,6,7,8 — 1–3 done)
1. Merge `feat/wt-integrate` → `feat/borrow-lgw`, run analyze + tests.
2. Finish `feat/comp-followups` task 3 (full-screen cover), merge.
3. Finish `feat/tabbar-medium` (TODO item 5 Medium: label flip, accessory scene, motion frames), merge.
4. Fidelity (user priority): TODO items 6 (clear-glass edges, group 4) and 8 (photo refits).
   Rule: accept only runs with gains and zero losses vs build/fidelity/g13-2 (55/75).
5. Then the usability pass (memory: usability-pass-after-fidelity).

## Rules (unchanged)
Never `dart pub publish` without the user's request (dry-run ok). No push/PR/merge to main
without the user. Commits end with `Co-Authored-By:`. Reference sim E7A87B4A only for fidelity.

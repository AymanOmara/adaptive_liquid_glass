# Full-screen cover drag

Progress: 3/3 (100%). The drag remains an explicit optional extension;
SwiftUI has no corresponding gesture to reproduce.

- [x] Give cover drag an independent configurable policy and repair gesture handling.
- [x] Verify thresholds, cancellations, return motion, navigation and both render paths.
- [x] Update API documentation, README limitations and validation results after tests pass.


Implementation:
- Public `GlassFullScreenCoverDragConfiguration` controls distance, fling
  speed, upward resistance and return spring on both rendering paths.
- Default 0.25 / 700 / 0.3 behavior is preserved, but cover metrics no longer
  import SheetMetrics or alias its spring. Infinity disables fling dismissal.
- Resistance is applied once to cumulative raw travel, so pointer frequency
  cannot change it and reversing to the starting point restores zero offset.
- Cancellation returns to rest; a new drag interrupts a return without an old
  completion resetting it. Disabling clears offsets. Downward velocity alone
  cannot dismiss a cover still above rest. A stale dismiss callback cannot
  pop a newer route, and PopScope vetoes remain respected.

Validation:
- 1,521 full-suite Flutter tests passed.
- 41 final cover tests passed, including the subsequent queued-dismiss
  regression; 156 cover/reference/API checks passed before that extra case.
- Analysis clean; default-disabled behavior, measured route transitions,
  accessibility dismissal, Reduce Motion, child scrolling and both iOS /
  Material custom policies are covered. These are Flutter gesture/routing
  tests, not a claim of matching a nonexistent SwiftUI drag gesture.
- README Known limitations bullet removed only after focused checks passed;
  the cover API section now documents the independent extension and example.

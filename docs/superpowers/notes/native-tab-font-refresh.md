# Native tab font refresh

Progress: 3/3 (100%).

- [x] Inspect font eligibility and cached image lifecycle.
- [x] Refresh native templates after font changes and verify late font loading.
- [x] Run tab regressions and analysis, then update README limitations.

Custom font support remains constrained by glyph overflow beyond the fixed
UIKit template box. This pass addresses stale cached templates when an eligible
font becomes available after the native bar mounts.

The real FontLoader regression fails without the listener (one native creation
instead of two). With it, the replacement PNG differs from the missing-font
image and exactly matches the loaded Cupertino glyph. Repeated notifications
supersede pending images; disposal unregisters the listener and invalidates work.

Validation: all 102 tab tests passed; the final regression passed after test
lint fixes, and analysis reports no issues. README and changelog updated only
after validation. No custom-font limitation was removed without verification.

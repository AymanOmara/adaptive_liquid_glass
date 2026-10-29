# Native tab dot badges

Progress: 3/3 (100%).

- [x] Verify UIKit renders an empty badge as a visible dot, including updates.
- [x] Enable the public native path for dot badges and test eligibility.
- [x] Run regressions and analysis, then narrow the README restriction.

The existing native payload already carried empty badge strings. Flutter's
eligibility check excluded them pending native geometry verification.

Production UIKit control on iOS 26.4: dot is exactly 18x18 points in both
appearances, covering 250.22/254.67 square points under the red-pixel threshold.
Changing selection preserves its size, `22` widens it, and null removes every
red badge pixel. The new metadata regression fails before removing the guard.

The final device regression exercises public GlassTabBar with SF Symbols and
Material bitmap templates in both appearances; all four scenes pass the same
pixel checks. It verifies a single UiKitView, controlled selection and removal
of the native host at disposal. All 104 tab tests pass and analysis is clean.
README restrictions narrowed only after the public device integration passed.

# Photo codec stalls — 2026-10-24

Progress: 3/3 (100%).

- [x] Bound codec inactivity while preserving slow but progressing conversions.
- [x] Test inactivity, progress, timeout cleanup and native compilation.
- [x] Update the README after validation.

The device's codec speed remains a limitation. This work prevents a stalled
conversion loop from keeping a photo import active indefinitely.

Implementation: a monotonic inactivity clock resets when input is queued,
decoder/encoder output arrives or the codec reports its output format. Both
polling loops check for 30 seconds without progress. Timeout follows the existing
conversion-failure path: release resources, discard partial output, keep the
original video and return `conversionFailed`. There is no overall duration cap.
This cannot interrupt native codec methods that block instead of returning from
their bounded poll. No conversion-speed improvement is claimed.

Validation before README update:

- 8 Android JVM tests passed (3 existing cache tests, 4 inactivity-clock cases,
  1 timeout/fallback/retry case). The production Android plugin compiled.
- Clock tests cover the exact 30-second boundary, hours of ongoing progress,
  inactivity after progress, monotonic counter wrap and invalid timeouts.
- The fallback test runs the production conversion wrapper with an injected
  stalled encoder, checking partial-file deletion, original preservation and
  successful retry. It does not simulate a real vendor codec or measure speed.
- 38 Flutter picker tests passed, including conversion-failure parsing.
- Logs: `/tmp/photo-codec-stall-tests.log` and
  `/tmp/photo-codec-stall-flutter.log`. `git diff --check` passed.

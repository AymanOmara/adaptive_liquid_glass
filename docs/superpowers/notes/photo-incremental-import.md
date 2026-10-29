# Incremental photo import — 2026-10-24

Progress: 4/4 (100%).

- [x] Add optional per-item callbacks through Dart and both native importers.
- [x] Preserve files already delivered if a later Android item fails.
- [x] Verify callback ordering, failures, disposal, native compilation and regressions.
- [x] Narrow the README after validation.

The final picker result and `onPicked` still wait for the complete import.
This extension exposes ready files earlier without claiming faster conversion.

Implementation:

- Both public entry points accept optional `onItemReady`. A unique per-request
  method channel carries each completed native import. Dart deduplicates by
  local path, reconciles the final result for older native plugins, reports
  callback errors without aborting the import and unregisters in `finally`.
- iOS publishes on the main actor between sequential imports. Android posts
  notifications on its main thread and uses per-item cache transactions when
  incremental delivery is enabled. A later failure removes only its own
  partial files, preserving paths already given to the app. Without the
  callback Android retains its previous whole-batch rollback.
- The widget suppresses ready and final callbacks after disposal. The final
  callback still contains all items, so consumers should avoid processing the
  same file twice when using both callbacks.

Validation: initial 50 focused Flutter picker tests passed, followed by the
complete 1,538-test Flutter suite including the final batch-callback regression;
10 Android JVM tests passed and the Android plugin compiled. The iOS simulator
debug build passed. Static analysis and `git diff --check` are clean.
These are callback/transaction tests and native compilation, not a repeated
system-picker UI session or a measured conversion-speed improvement.

Logs: `/tmp/photo-incremental-full-suite.log`,
`/tmp/photo-incremental-android.log`, `/tmp/photo-incremental-ios.log`,
`/tmp/photo-incremental-analyze.log`. README narrowed only after validation.

# Photo cache reliability — 2026-10-24

Progress: 3/3 (100%).

- [x] Roll back unsuccessful Android imports and report native cleanup failures.
- [x] Test rollback, preservation of earlier picks, failed cleanup and retry.
- [x] Update the README only after checks pass.

Scope: reduce orphaned cache files without changing the picker result contract.
Large-file latency, OS cache eviction and native picker selection caps remain.

Implementation:

- Android places each batch in a unique directory beneath the existing cache
  root. Any import exception rolls back that batch, including successful items
  preceding the failure and the current partial file. Older batches remain intact.
  Rollback cleanup failures are attached to the original exception.
- iOS removes a partial destination when the provider copy throws, preserving
  the source and the original error. Failed conversions already removed their
  partial outputs and continue to return the original media.
- Native explicit cleanup treats a missing directory as success and reports
  filesystem failure as `cleanup_failed`. iOS resets its active-cleanup flag on
  both outcomes. Android's serial executor still orders cleanup and imports.

Validation:

- 3 Android JVM tests passed against the production cache helper, including a
  failed batch after successful/partial copies, earlier-pick preservation,
  retry, denied deletion, nested cleanup and an invalid root. The Gradle test
  task also compiles the production Android plugin.
- 6 Swift filesystem checks passed against the production helper: interrupted
  copy cleanup, source preservation/successful retry, nested removal, missing
  cache, denied deletion and cleanup retry. Run with `swiftc` on the helper and
  `tool/native/test_photo_cache.swift`, then execute the resulting binary.
- 38 Flutter picker tests passed, including cleanup failure/retry on both hosts.
- iOS simulator debug build passed after refreshing CocoaPods to include the
  new source. No simulator was booted and no real picker interaction was rerun.
- Logs: `/tmp/photo-cache-android-tests.log`, `/tmp/photo-cache-flutter-tests.log`,
  `/tmp/photo-cache-ios-build.log`. README narrowed after these checks passed;
  the remaining Photos picker limitation was retained.
- Static analysis and `git diff --check` passed.

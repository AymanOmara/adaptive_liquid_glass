# Native checks

Run `tool/native/run_ios_tests.sh` from any directory. It compiles and runs the
Swift photo-cache filesystem checks, then runs the native glass lifecycle,
batching and system tab-bar integration suites in separate app launches.

Requires macOS, Xcode, Flutter, CocoaPods and an installed iOS 26+ simulator
runtime. By default the runner creates an isolated iPhone 17 Pro simulator
and deletes it on exit, including after a failed test. It prefers iOS 26 when
available. To reuse a booted simulator without deleting it:

```sh
IOS_DEVICE_ID=<simulator-uuid> tool/native/run_ios_tests.sh
```

`.github/workflows/native-ios.yml` runs the same checks for pull requests and
pushes to main on macOS 26, and can also be dispatched manually. A missing
runtime causes a download attempt in CI; the local script instead fails with
an actionable error. Tests never silently skip for a missing runtime.

Simulator checks protect native lifecycle and composition behavior. They do
not replace profile measurements of GPU memory, frame times or picker
conversion performance on physical devices.

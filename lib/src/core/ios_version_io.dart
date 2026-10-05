import 'dart:io' show Platform;

/// The iOS version string when actually running on iOS, else null.
///
/// Checks the real OS (`Platform.isIOS`), not `defaultTargetPlatform`, so
/// a test host overridden to iOS never reports its own OS version.
///
/// "Designed for iPad" apps on a Mac also report `Platform.isIOS`, and the
/// string may then carry the macOS version. That is still right: macOS 26
/// has the same Liquid Glass (native), and below 26 the major version is
/// under 26, so auto falls back to the shader.
String? iosVersionString() =>
    Platform.isIOS ? Platform.operatingSystemVersion : null;

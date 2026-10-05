import 'dart:io' show Platform;

/// The iOS version string when actually running on iOS, else null.
///
/// Checks the real OS (`Platform.isIOS`), not `defaultTargetPlatform`, so
/// a test host overridden to iOS never reports its own OS version.
String? iosVersionString() =>
    Platform.isIOS ? Platform.operatingSystemVersion : null;

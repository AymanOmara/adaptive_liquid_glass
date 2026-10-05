import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the major version of an iOS version string', () {
    // NSProcessInfo.operatingSystemVersionString, as dart:io reports it.
    expect(parseIosMajorVersion('Version 26.4 (Build 23E244)'), 26);
    expect(parseIosMajorVersion('Version 18.6.2 (Build 22G100)'), 18);
    expect(parseIosMajorVersion('Version 27.0 (Build 24A5)'), 27);
    expect(parseIosMajorVersion('26.0'), 26);
    expect(parseIosMajorVersion('iOS 26'), 26);
  });

  test('unparseable version strings give null', () {
    expect(parseIosMajorVersion(''), isNull);
    expect(parseIosMajorVersion('Version unknown'), isNull);
  });

  test('current() knows the iOS version only on a real iOS host', () {
    // Tests run on macOS or Linux, even under an iOS target platform
    // override: the host OS version must not be taken for an iOS one.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(GlassEnvironment.current().platform, TargetPlatform.iOS);
    expect(GlassEnvironment.current().iosMajorVersion, isNull);
  });
}

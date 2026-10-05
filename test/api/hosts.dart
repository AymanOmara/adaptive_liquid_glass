import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// iOS only: the shader path.
final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

/// Android only: the Material path.
final android = TargetPlatformVariant.only(TargetPlatform.android);

/// A shader-capable iOS 18 environment (the shader is the default there) (or Android when the variant says so).
void shaderEnv() {
  GlassPlatform.instance.debugEnvironment = GlassEnvironment(
    platform: defaultTargetPlatform,
    iosMajorVersion: defaultTargetPlatform == TargetPlatform.iOS ? 18 : null,
    reduceTransparency: false,
    shaderSupported: true,
  );
}

/// A widgets-only host with a MediaQuery from the test view.
Widget plainHost(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    MediaQuery(
      data: MediaQueryData.fromView(
        WidgetsBinding.instance.platformDispatcher.implicitView!,
      ),
      child: Directionality(
        textDirection: direction,
        child: Center(child: child),
      ),
    );

/// A MaterialApp host (shortcuts, focus traversal, Material theme).
Widget appHost(Widget child) => MaterialApp(
  theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
  home: Scaffold(body: Center(child: child)),
);

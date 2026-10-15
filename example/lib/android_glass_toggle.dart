import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/material.dart';

/// Whether the example draws the iOS Liquid Glass look on Android
/// ([LiquidGlassThemeData.supportLiquidGlassOnAndroid]). Starts from
/// `--dart-define=ANDROID_GLASS=true`; [AndroidGlassSwitch] flips it.
final ValueNotifier<bool> androidLiquidGlass = ValueNotifier(
  const bool.fromEnvironment('ANDROID_GLASS'),
);

/// [LiquidGlassTheme] with [data], its `supportLiquidGlassOnAndroid`
/// following [androidLiquidGlass].
class AndroidGlassTheme extends StatelessWidget {
  /// Creates the theme.
  const AndroidGlassTheme({super.key, required this.data, required this.child});

  /// The rest of the theme.
  final LiquidGlassThemeData data;

  /// The app.
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: androidLiquidGlass,
    builder: (context, on, child) => LiquidGlassTheme(
      data: data.copyWith(supportLiquidGlassOnAndroid: on),
      child: child!,
    ),
    child: child,
  );
}

/// "iOS glass" with a toggle for [androidLiquidGlass]; nothing off
/// Android, where the flag has no effect.
class AndroidGlassSwitch extends StatelessWidget {
  /// Creates the switch.
  const AndroidGlassSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<bool>(
      valueListenable: androidLiquidGlass,
      builder: (context, on, _) => LiquidGlass(
        padding: const EdgeInsetsDirectional.only(
          start: 16,
          end: 8,
          top: 6,
          bottom: 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('iOS glass'),
            const SizedBox(width: 8),
            GlassToggle(
              value: on,
              onChanged: (value) => androidLiquidGlass.value = value,
            ),
          ],
        ),
      ),
    );
  }
}

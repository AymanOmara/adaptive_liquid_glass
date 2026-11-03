import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart';

/// Non-glass button reference twin; rows match SystemButtonsReference.swift.
class SystemButtonsTwin extends StatelessWidget {
  /// Creates the light or dark reference layout.
  const SystemButtonsTwin({super.key, required this.dark});

  /// Whether to use the dark system appearance.
  final bool dark;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(platformBrightness: dark ? Brightness.dark : Brightness.light),
    child: CupertinoTheme(
      data: CupertinoThemeData(
        brightness: dark ? Brightness.dark : Brightness.light,
        primaryColor: GlassSystemColors.blue,
      ),
      child: Builder(
        builder: (context) => DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle,
          child: ColoredBox(
            color: dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
            child: Stack(
              children: [
                for (var column = 0; column < 2; column++)
                  for (var row = 0; row < 8; row++)
                    Positioned(
                      left: (column == 0 ? 100 : 300) - 90,
                      top: (row + 1) * 100 - 40,
                      width: 180,
                      height: 80,
                      child: Center(
                        child: GlassButton(
                          onPressed: column == 0 ? () {} : null,
                          style: switch (row) {
                            3 || 4 => GlassButtonStyle.borderedProminent,
                            5 || 7 => GlassButtonStyle.borderless,
                            6 => GlassButtonStyle.plain,
                            _ => GlassButtonStyle.bordered,
                          },
                          role: row == 2 || row == 4 || row == 7
                              ? GlassButtonRole.destructive
                              : GlassButtonRole.none,
                          tint: row == 1 || row == 3 || row == 5
                              ? const Color(0xFF0080FF)
                              : null,
                          child: const Text('Button'),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

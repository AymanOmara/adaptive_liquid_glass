import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A glass dialog card holding glass buttons (`-twin nestedglassdialog`,
/// `-twin nestedglassdialogdark`): the buttons are glass nested in a
/// `LiquidGlass`'s content, so each must keep its own crisp capsule and
/// rim instead of merging into the card. Null for other scenes.
Widget? nestedGlassTwin(String scene) => switch (scene) {
  'nestedglassdialog' => const _NestedGlassDialog(dark: false),
  'nestedglassdialogdark' => const _NestedGlassDialog(dark: true),
  _ => null,
};

class _NestedGlassDialog extends StatelessWidget {
  const _NestedGlassDialog({required this.dark});

  final bool dark;

  Widget _row(String caption, GlassButtonStyle style, Color text) => Column(
    spacing: 12,
    children: [
      Text(caption, style: TextStyle(fontSize: 13, color: text)),
      Row(
        spacing: 12,
        children: [
          Expanded(
            child: GlassButton(
              onPressed: () {},
              style: style,
              child: const Text('Cancel'),
            ),
          ),
          Expanded(
            child: GlassButton(
              onPressed: () {},
              style: style,
              role: GlassButtonRole.destructive,
              child: const Text('Delete'),
            ),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final text = dark ? CupertinoColors.white : CupertinoColors.black;
    final page = Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const [
                    Color(0xFF0B1E3F),
                    Color(0xFF3B1450),
                    Color(0xFF0E3B2E),
                  ]
                : const [
                    Color(0xFF3A7BD5),
                    Color(0xFFF2994A),
                    Color(0xFFEB5757),
                  ],
          ),
        ),
        child: SizedBox.expand(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: LiquidGlass(
                shape: const GlassShape.rect(32),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 16,
                  children: [
                    Text(
                      'Delete transaction?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: text,
                      ),
                    ),
                    _row('glass', GlassButtonStyle.glass, text),
                    _row(
                      'glassProminent',
                      GlassButtonStyle.glassProminent,
                      text,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (!dark) return page;
    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(platformBrightness: Brightness.dark),
      child: Theme(
        data: ThemeData(brightness: Brightness.dark),
        child: CupertinoTheme(
          data: const CupertinoThemeData(brightness: Brightness.dark),
          child: page,
        ),
      ),
    );
  }
}

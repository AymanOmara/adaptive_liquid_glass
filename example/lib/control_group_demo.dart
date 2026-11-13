import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// `GlassControlGroup` showcase. Run with
/// `flutter run -t lib/control_group_demo.dart`.
Future<void> main() async {
  await AdaptiveLiquidGlass.initialize();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ControlGroupDemo(),
    ),
  );
}

/// The demo page.
class ControlGroupDemo extends StatefulWidget {
  /// Creates the page.
  const ControlGroupDemo({super.key});

  @override
  State<ControlGroupDemo> createState() => _ControlGroupDemoState();
}

class _ControlGroupDemoState extends State<ControlGroupDemo> {
  int _match = 1;

  Widget _icon(IconData icon, String label, [VoidCallback? onTap]) =>
      GlassButton.icon(
        onPressed: onTap ?? () {},
        icon: icon,
        semanticLabel: label,
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SizedBox.expand(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3A7BD5), Color(0xFFF2994A), Color(0xFFEB5757)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ControlGroup',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 28),
                _caption('Capsule with dividers — $_match of 5'),
                GlassControlGroup(
                  children: [
                    _icon(
                      CupertinoIcons.chevron_up,
                      'Previous',
                      () => setState(() => _match = (_match - 1).clamp(1, 5)),
                    ),
                    _icon(
                      CupertinoIcons.chevron_down,
                      'Next',
                      () => setState(() => _match = (_match + 1).clamp(1, 5)),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _caption('Without dividers (toolbar look)'),
                GlassControlGroup(
                  dividers: false,
                  children: [
                    _icon(CupertinoIcons.reply, 'Reply'),
                    _icon(CupertinoIcons.share, 'Share'),
                  ],
                ),
                const SizedBox(height: 28),
                _caption('Three members'),
                GlassControlGroup(
                  children: [
                    _icon(CupertinoIcons.bold, 'Bold'),
                    _icon(CupertinoIcons.italic, 'Italic'),
                    _icon(CupertinoIcons.underline, 'Underline'),
                  ],
                ),
                const SizedBox(height: 28),
                _caption('Menu style'),
                GlassControlGroup.menu(
                  items: [
                    GlassMenuItem(
                      label: 'Copy',
                      icon: CupertinoIcons.doc_on_doc,
                      onSelected: () {},
                    ),
                    GlassMenuItem(
                      label: 'Delete',
                      icon: CupertinoIcons.trash,
                      destructive: true,
                      onSelected: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _caption(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: const TextStyle(color: Colors.white70)),
  );
}

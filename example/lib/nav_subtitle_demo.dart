import 'dart:io' show Platform;

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'android_glass_toggle.dart';

// `navigationSubtitle` and the scroll edge styles. Own entry point:
// `flutter run -t lib/nav_subtitle_demo.dart --dart-define=PAGE=large`
// with PAGE one of `inline`, `large`, `uniform`, `progressive`, `hard`,
// `hidden`.
Future<void> main() async {
  await AdaptiveLiquidGlass.initialize(mode: GlassRenderMode.shader);
  // `SIMCTL_CHILD_PAGE=hard xcrun simctl launch ...` also picks the page.
  final page =
      Platform.environment['PAGE'] ??
      const String.fromEnvironment('PAGE', defaultValue: 'large');
  runApp(
    AndroidGlassTheme(
      data: const LiquidGlassThemeData(defaultMode: GlassRenderMode.shader),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: switch (page) {
          'inline' => const _InlinePage(),
          'large' => const _LargePage(GlassScrollEdgeStyle.uniform),
          _ => _LargePage(
            GlassScrollEdgeStyle.values.firstWhere((s) => s.name == page),
          ),
        },
      ),
    ),
  );
}

final _actions = [
  GlassButton.icon(
    onPressed: () {},
    icon: CupertinoIcons.ellipsis,
    semanticLabel: 'More',
  ),
];

Widget _row(int i) => Padding(
  padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
  child: SizedBox(
    height: 56,
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        'Message $i',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.primaries[i % Colors.primaries.length],
        ),
      ),
    ),
  ),
);

class _InlinePage extends StatelessWidget {
  const _InlinePage();

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: GlassNavigationBar(
      title: const Text('Inbox'),
      subtitle: const Text('3 unread'),
      actions: _actions,
    ),
    body: ListView.builder(
      padding: const EdgeInsets.only(top: 110),
      itemBuilder: (_, i) => _row(i),
    ),
  );
}

class _LargePage extends StatelessWidget {
  const _LargePage(this.style);

  final GlassScrollEdgeStyle style;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverGlassNavigationBar(
          largeTitle: const Text('Inbox'),
          subtitle: const Text('3 unread'),
          scrollEdgeStyle: style,
          actions: _actions,
        ),
        SliverList.builder(itemCount: 80, itemBuilder: (_, i) => _row(i)),
      ],
    ),
  );
}

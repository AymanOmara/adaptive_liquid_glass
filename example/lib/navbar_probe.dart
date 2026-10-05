import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The `-controls navbar` SwiftUI screen (ControlScenes.swift) in Flutter,
/// scrolled to `--dart-define=SCROLL_Y=<pt>`, for side-by-side comparison:
/// `flutter run -t lib/navbar_probe.dart --dart-define=SCROLL_Y=40`.
void main() {
  const y = int.fromEnvironment('SCROLL_Y');
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: Colors.white),
      home: Scaffold(
        body: CustomScrollView(
          controller: ScrollController(initialScrollOffset: y.toDouble()),
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverGlassNavigationBar(
              largeTitle: const Text('Inbox'),
              actions: [
                GlassButton.icon(
                  onPressed: () {},
                  icon: CupertinoIcons.square_pencil,
                ),
                GlassButton.icon(
                  onPressed: () {},
                  icon: CupertinoIcons.ellipsis,
                ),
              ],
            ),
            SliverList.builder(
              itemCount: 60,
              itemBuilder: (_, i) => SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 16,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text('Row $i', style: const TextStyle(fontSize: 17)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

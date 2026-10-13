import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

/// Controls whose animation controllers may go untouched until disposed:
/// each must unmount cleanly without ever being pressed.
final _controls = <String, Widget>{
  'GlassToggle': GlassToggle(value: false, onChanged: (_) {}),
  'GlassSlider': SizedBox(
    width: 200,
    child: GlassSlider(value: 0.5, onChanged: (_) {}),
  ),
  'GlassSegmentedControl': SizedBox(
    width: 300,
    child: GlassSegmentedControl<int>(
      segments: const [
        GlassSegment(value: 0, label: Text('A')),
        GlassSegment(value: 1, label: Text('B')),
      ],
      selected: 0,
      onChanged: (_) {},
    ),
  ),
  'GlassRefresh': SizedBox(
    width: 300,
    height: 400,
    child: GlassRefresh(
      onRefresh: () async {},
      child: ListView(children: const [SizedBox(height: 800)]),
    ),
  ),
  'GlassProgressIndicator': const SizedBox(
    width: 200,
    child: GlassProgressIndicator(value: 0.5),
  ),
  'GlassSwipeActions': const SizedBox(
    width: 300,
    child: GlassSwipeActions(child: SizedBox(height: 44)),
  ),
  'GlassTabBar': SizedBox(
    width: 360,
    child: GlassTabBar(
      items: const [
        GlassTabBarItem(icon: CupertinoIcons.clock_fill, label: 'History'),
        GlassTabBarItem(icon: CupertinoIcons.gear_solid, label: 'Settings'),
      ],
      selectedIndex: 0,
      onSelected: (_) {},
    ),
  ),
};

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  const both = TargetPlatformVariant({
    TargetPlatform.iOS,
    TargetPlatform.android,
  });

  for (final MapEntry(key: name, value: control) in _controls.entries) {
    testWidgets('$name never touched disposes cleanly', (t) async {
      shaderEnv();
      await t.pumpWidget(appHost(control));
      await t.pump();
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    }, variant: both);
  }
}

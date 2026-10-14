import 'dart:typed_data';

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/color_picker/eyedropper.dart';
import 'package:adaptive_liquid_glass/src/color_picker/glass_color_picker_panel.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

const _red = Color(0xFFFF0000);
const _blue = Color(0xFF0000FF);

/// A page: red on the top half, blue on the bottom, and a button that
/// runs the eyedropper.
class _Page extends StatefulWidget {
  const _Page();

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  Color? picked;
  bool done = false;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ColoredBox(
          color: _red,
          child: Center(
            child: Builder(
              builder: (context) => GestureDetector(
                onTap: () async {
                  final c = await pickColorFromApp(context);
                  setState(() {
                    picked = c;
                    done = true;
                  });
                },
                child: const Text('Drop'),
              ),
            ),
          ),
        ),
      ),
      const Expanded(
        child: ColoredBox(color: _blue, child: SizedBox.expand()),
      ),
    ],
  );
}

Future<void> _start(WidgetTester t) async {
  t.view.physicalSize = const Size(400, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(const MaterialApp(home: _Page()));
  await t.tap(find.text('Drop'));
  // The capture is real raster work.
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await t.pump();
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await t.pump();
}

_PageState _state(WidgetTester t) => t.state(find.byType(_Page));

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  group('colorAtPixel', () {
    // 2 x 2 RGBA: red, green / blue, white.
    final bytes = ByteData.sublistView(
      Uint8List.fromList([
        255, 0, 0, 255, 0, 255, 0, 255, //
        0, 0, 255, 255, 255, 255, 255, 255,
      ]),
    );
    test('reads the pixel at a point', () {
      expect(colorAtPixel(bytes, 2, 2, const Offset(0.5, 0.5)), _red);
      expect(
        colorAtPixel(bytes, 2, 2, const Offset(1.5, 0.2)),
        const Color(0xFF00FF00),
      );
      expect(colorAtPixel(bytes, 2, 2, const Offset(0.1, 1.9)), _blue);
    });
    test('clamps points off the image to its edge', () {
      expect(colorAtPixel(bytes, 2, 2, const Offset(-5, -5)), _red);
      expect(
        colorAtPixel(bytes, 2, 2, const Offset(9, 9)),
        const Color(0xFFFFFFFF),
      );
    });
  });

  testWidgets('the loupe opens over the app and a tap picks the pixel', (
    t,
  ) async {
    await _start(t);
    expect(find.byType(EyedropperLoupe), findsOneWidget);
    await t.tapAt(const Offset(200, 700));
    await t.pump();
    expect(find.byType(EyedropperLoupe), findsNothing);
    expect(_state(t).done, isTrue);
    expect(_state(t).picked, _blue);
  });

  testWidgets('dragging moves the loupe; letting go picks under it', (t) async {
    await _start(t);
    // The loupe starts at the screen's centre and follows the drag.
    final g = await t.startGesture(const Offset(300, 300));
    await g.moveBy(const Offset(0, 100));
    await g.moveBy(const Offset(0, 100));
    await t.pump();
    expect(t.getCenter(find.byType(EyedropperLoupe)), const Offset(200, 600));
    await g.up();
    await t.pump();
    expect(_state(t).picked, _blue);
  });

  testWidgets('GlassColorPicker: the eyedropper hides the sheet, picks a '
      'pixel of the app and reopens the sheet with it', (t) async {
    shaderEnv();
    t.view.physicalSize = const Size(400, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var value = const Color(0x80FF0000);
    await t.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              GlassColorPicker(
                label: const Text('Accent'),
                value: value,
                onChanged: (c) => setState(() => value = c),
              ),
              const Expanded(
                child: ColoredBox(color: _blue, child: SizedBox.expand()),
              ),
            ],
          ),
        ),
      ),
    );
    await t.tap(find.text('Accent'));
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Eyedropper'));
    // The sheet's exit, then the capture (real raster work).
    for (var i = 0; i < 4; i++) {
      await t.pumpAndSettle();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    await t.pump();
    expect(find.byType(GlassColorPickerPanel), findsNothing);
    expect(find.byType(EyedropperLoupe), findsOneWidget);
    await t.tapAt(const Offset(200, 150));
    await t.pumpAndSettle();
    // The pixel's colour, at the colour's opacity.
    expect(value, _blue.withValues(alpha: 0x80 / 255));
    expect(find.byType(GlassColorPickerPanel), findsOneWidget);
  }, variant: ios);

  testWidgets('the panel shows the eyedropper only with onEyedropper', (
    t,
  ) async {
    shaderEnv();
    var taps = 0;
    await t.pumpWidget(
      appHost(
        SingleChildScrollView(
          child: GlassColorPickerPanel(
            value: _red,
            onChanged: (_) {},
            onEyedropper: () => taps++,
          ),
        ),
      ),
    );
    await t.tap(find.bySemanticsLabel('Eyedropper'));
    expect(taps, 1);
    await t.pumpWidget(
      appHost(
        SingleChildScrollView(
          child: GlassColorPickerPanel(value: _red, onChanged: (_) {}),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Eyedropper'), findsNothing);
  }, variant: ios);
}

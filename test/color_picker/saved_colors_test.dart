import 'package:adaptive_liquid_glass/src/color_picker/color_hex.dart';
import 'package:adaptive_liquid_glass/src/color_picker/color_picker_metrics.dart';
import 'package:adaptive_liquid_glass/src/color_picker/glass_color_picker_panel.dart';
import 'package:adaptive_liquid_glass/src/color_picker/saved_colors.dart';
import 'package:adaptive_liquid_glass/src/color_picker/spectrum_map.dart';
import 'package:adaptive_liquid_glass/src/color_picker/spectrum_thumb.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

const _blue = Color(0xFF007AFF);

class _Panel extends StatefulWidget {
  const _Panel({this.saved, this.onSaved});

  final List<Color>? saved;
  final ValueChanged<List<Color>>? onSaved;

  @override
  State<_Panel> createState() => _PanelState();
}

class _PanelState extends State<_Panel> {
  Color value = _blue;
  final picks = <Color>[];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: GlassColorPickerPanel(
      value: value,
      onChanged: (c) => setState(() {
        value = c;
        picks.add(c);
      }),
      savedColors: widget.saved,
      onSavedColorsChanged: widget.onSaved,
    ),
  );
}

void _screen(WidgetTester t) {
  t.view.physicalSize = const Size(386, 1400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Finder _saved(Color c) =>
    find.bySemanticsLabel('Saved colour ${formatHexColor(c)}');

void main() {
  setUp(() {
    GlassProgram.instance.debugReset(skipLoad: true);
    SavedColors.debugReset();
  });
  tearDown(() => GlassPlatform.instance.debugReset());

  test("UIKit's saved colours: black, blue, green, yellow, red (measured)", () {
    expect(SavedColors.defaults, const [
      Color(0xFF000000),
      Color(0xFF0161FD),
      Color(0xFF32C759),
      Color(0xFFFFCC02),
      Color(0xFFFF3A30),
    ]);
  });

  testWidgets('the row shows the saved colours and a + button', (t) async {
    shaderEnv();
    _screen(t);
    await t.pumpWidget(appHost(const _Panel()));
    for (final c in SavedColors.defaults) {
      expect(_saved(c), findsOneWidget);
    }
    expect(find.bySemanticsLabel('Add to saved colours'), findsOneWidget);
  }, variant: ios);

  testWidgets('geometry: 29-pt circles 46.07 apart, level with the swatch', (
    t,
  ) async {
    shaderEnv();
    _screen(t);
    await t.pumpWidget(appHost(const _Panel()));
    final swatch = t.getRect(find.byKey(const ValueKey('current-colour')));
    final first = t.getRect(_saved(SavedColors.defaults.first));
    final second = t.getRect(_saved(SavedColors.defaults[1]));
    final add = t.getRect(find.bySemanticsLabel('Add to saved colours'));
    expect(first.width, moreOrLessEquals(ColorPickerMetrics.savedSwatch));
    expect(first.top, moreOrLessEquals(swatch.top));
    expect(
      first.left - swatch.right,
      moreOrLessEquals(ColorPickerMetrics.savedStart),
    );
    expect(
      second.left - first.left,
      moreOrLessEquals(ColorPickerMetrics.savedPitch),
    );
    expect(
      add.left - first.left,
      moreOrLessEquals(5 * ColorPickerMetrics.savedPitch),
    );
  }, variant: ios);

  testWidgets('tapping a saved colour picks it', (t) async {
    shaderEnv();
    _screen(t);
    await t.pumpWidget(appHost(const _Panel()));
    await t.tap(_saved(SavedColors.defaults[2]));
    await t.pump();
    final state = t.state<_PanelState>(find.byType(_Panel));
    expect(state.picks.last, SavedColors.defaults[2]);
  }, variant: ios);

  testWidgets('+ saves the current colour, kept in memory across sheets', (
    t,
  ) async {
    shaderEnv();
    _screen(t);
    await t.pumpWidget(appHost(const _Panel()));
    await t.tap(find.bySemanticsLabel('Add to saved colours'));
    await t.pump();
    expect(SavedColors.shared.value.last, _blue);
    // A new panel shows it too.
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(appHost(const _Panel()));
    expect(_saved(_blue), findsOneWidget);
  }, variant: ios);

  testWidgets('a long press removes a saved colour', (t) async {
    shaderEnv();
    _screen(t);
    await t.pumpWidget(appHost(const _Panel()));
    await t.longPress(_saved(SavedColors.defaults.first));
    await t.pump();
    expect(_saved(SavedColors.defaults.first), findsNothing);
    expect(SavedColors.shared.value, SavedColors.defaults.sublist(1));
  }, variant: ios);

  testWidgets('Spectrum: one map the height of the page; a tap picks the '
      'colour under it', (t) async {
    shaderEnv();
    _screen(t);
    await t.pumpWidget(appHost(const _Panel()));
    await t.tap(find.text('Spectrum'));
    await t.pumpAndSettle();
    final map = t.getRect(find.byType(SpectrumMap));
    expect(map.height, moreOrLessEquals(ColorPickerMetrics.pageHeight));
    // The pure green at the centre, a third of the way down.
    await t.tapAt(Offset(map.center.dx, map.top + map.height / 3));
    await t.pump();
    final state = t.state<_PanelState>(find.byType(_Panel));
    expect(state.picks.last, const Color(0xFF00FF00));
    // The thumb follows it.
    final thumb = t.getCenter(find.byType(SpectrumThumb));
    expect(thumb.dx, moreOrLessEquals(map.center.dx, epsilon: 0.5));
    expect(thumb.dy, moreOrLessEquals(map.top + map.height / 3, epsilon: 0.5));
  }, variant: ios);

  testWidgets('savedColors and onSavedColorsChanged replace the shared list', (
    t,
  ) async {
    shaderEnv();
    _screen(t);
    final changes = <List<Color>>[];
    await t.pumpWidget(
      appHost(_Panel(saved: const [Color(0xFF123456)], onSaved: changes.add)),
    );
    expect(_saved(const Color(0xFF123456)), findsOneWidget);
    expect(_saved(SavedColors.defaults.first), findsNothing);
    await t.tap(find.bySemanticsLabel('Add to saved colours'));
    await t.pump();
    expect(changes.single, const [Color(0xFF123456), _blue]);
    // The panel shows the change at once; the shared list is untouched.
    expect(_saved(_blue), findsOneWidget);
    expect(SavedColors.shared.value, SavedColors.defaults);
  }, variant: ios);
}

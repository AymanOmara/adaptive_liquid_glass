import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/color_picker/color_channel_slider.dart';
import 'package:adaptive_liquid_glass/src/color_picker/color_hex.dart';
import 'package:adaptive_liquid_glass/src/color_picker/color_picker_metrics.dart';
import 'package:adaptive_liquid_glass/src/color_picker/color_swatch_dot.dart';
import 'package:adaptive_liquid_glass/src/color_picker/color_value_field.dart';
import 'package:adaptive_liquid_glass/src/color_picker/glass_color_picker_panel.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

const _blue = Color(0xFF007AFF);

class _Harness extends StatefulWidget {
  const _Harness({
    this.enabled = true,
    this.supportsOpacity = true,
    this.semanticLabel,
    this.onChanged,
  });

  final bool enabled;
  final bool supportsOpacity;
  final String? semanticLabel;
  final ValueChanged<Color>? onChanged;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  Color value = _blue;

  @override
  Widget build(BuildContext context) => GlassColorPicker(
    label: const Text('Accent'),
    value: value,
    supportsOpacity: widget.supportsOpacity,
    semanticLabel: widget.semanticLabel,
    onChanged: widget.enabled
        ? (c) {
            setState(() => value = c);
            widget.onChanged?.call(c);
          }
        : null,
  );
}

/// An iPhone-wide, tall screen so the whole sheet content is on screen.
void _tall(WidgetTester t) {
  t.view.physicalSize = const Size(402, 1400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

Future<void> _open(WidgetTester t) async {
  await t.tap(find.text('Accent'));
  await t.pumpAndSettle();
}

/// The value field of [width] (hex: 96, opacity and channels: 73).
Finder _field(double width) => find.descendant(
  of: find.byWidgetPredicate((w) => w is ColorValueField && w.width == width),
  matching: find.byType(EditableText),
);

Finder get _hexField => _field(ColorPickerMetrics.hexFieldWidth);

Future<void> _sliders(WidgetTester t) async {
  await t.tap(find.text('Sliders'));
  await t.pumpAndSettle();
}

Future<void> _enterHex(WidgetTester t, String text) async {
  await t.enterText(_hexField, text);
  await t.pumpAndSettle();
}

Color _swatchColor(WidgetTester t) => t
    .widget<ColorSwatchDot>(
      find.descendant(
        of: find.byType(GlassColorPicker),
        matching: find.byType(ColorSwatchDot),
      ),
    )
    .color;

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  test("the grid's selection ring swaps at once, as UIKit's (measured)", () {
    expect(ColorPickerMetrics.selectionDuration, Duration.zero);
  });

  group('hex', () {
    test('parses #RRGGBB and #AARRGGBB, with or without #', () {
      expect(parseHexColor('#FF0000'), const Color(0xFFFF0000));
      expect(parseHexColor('00ff00'), const Color(0xFF00FF00));
      expect(parseHexColor('#80FF0000'), const Color(0x80FF0000));
      expect(parseHexColor(' #123456 '), const Color(0xFF123456));
    });

    test('rejects other text', () {
      expect(parseHexColor(''), isNull);
      expect(parseHexColor('#FFF'), isNull);
      expect(parseHexColor('#GG0000'), isNull);
      expect(parseHexColor('#FF00000'), isNull);
      expect(parseHexColor('#FF0000000'), isNull);
    });

    test('formats upper case, alpha only when translucent', () {
      expect(formatHexColor(const Color(0xFF007AFF)), '#007AFF');
      expect(formatHexColor(const Color(0x80007AFF)), '#80007AFF');
      expect(
        formatHexColor(const Color(0x80007AFF), withAlpha: false),
        '#007AFF',
      );
    });
  });

  testWidgets('the row shows the label and a swatch of the colour', (t) async {
    shaderEnv();
    await t.pumpWidget(appHost(const _Harness()));
    expect(find.text('Accent'), findsOneWidget);
    expect(_swatchColor(t), _blue);
    expect(find.byType(GlassColorPickerPanel), findsNothing);
  }, variant: ios);

  testWidgets('tapping the row opens a glass sheet with the panel', (t) async {
    shaderEnv();
    _tall(t);
    await t.pumpWidget(appHost(const _Harness()));
    await _open(t);
    expect(find.byType(GlassSheet), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(GlassSheet),
        matching: find.byType(GlassColorPickerPanel),
      ),
      findsOneWidget,
    );
    // UIKit's layout: the label as title, a close button, the opacity
    // slider with its percentage.
    expect(find.text('Accent'), findsNWidgets(2));
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    expect(find.byType(ColorChannelSlider), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    // The close button dismisses the sheet.
    await t.tap(find.bySemanticsLabel('Close'));
    await t.pumpAndSettle();
    expect(find.byType(GlassColorPickerPanel), findsNothing);
  }, variant: ios);

  testWidgets('Material: a list tile opening a bottom sheet', (t) async {
    shaderEnv();
    _tall(t);
    await t.pumpWidget(appHost(const _Harness()));
    expect(find.byType(ListTile), findsOneWidget);
    await _open(t);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(GlassColorPickerPanel), findsOneWidget);
    expect(find.byType(ColorChannelSlider), findsOneWidget);
  }, variant: android);

  testWidgets('tapping a grid swatch applies it live', (t) async {
    shaderEnv();
    _tall(t);
    final picked = <Color>[];
    await t.pumpWidget(appHost(_Harness(onChanged: picked.add)));
    await _open(t);
    await t.tap(find.bySemanticsLabel('#FFFFFF'));
    await t.pumpAndSettle();
    expect(picked, [const Color(0xFFFFFFFF)]);
    expect(find.byType(GlassColorPickerPanel), findsOneWidget);
    expect(_swatchColor(t), const Color(0xFFFFFFFF));
    await _sliders(t);
    expect(t.widget<EditableText>(_hexField).controller.text, 'FFFFFF');
  }, variant: ios);

  testWidgets('the hex field parses #RRGGBB and #AARRGGBB', (t) async {
    shaderEnv();
    _tall(t);
    final picked = <Color>[];
    await t.pumpWidget(appHost(_Harness(onChanged: picked.add)));
    await _open(t);
    await _sliders(t);
    await _enterHex(t, '#FF0000');
    expect(picked.last, const Color(0xFFFF0000));
    await _enterHex(t, '80FF0000');
    expect(picked.last, const Color(0x80FF0000));
    expect(_swatchColor(t), const Color(0x80FF0000));
    // Not a colour: nothing changes.
    await _enterHex(t, '#FF00');
    expect(picked.length, 2);
  }, variant: ios);

  testWidgets('without opacity there is no slider and the colour is opaque', (
    t,
  ) async {
    shaderEnv();
    _tall(t);
    final picked = <Color>[];
    await t.pumpWidget(
      appHost(_Harness(supportsOpacity: false, onChanged: picked.add)),
    );
    await _open(t);
    expect(find.byType(ColorChannelSlider), findsNothing);
    expect(find.text('OPACITY'), findsNothing);
    await _sliders(t);
    await _enterHex(t, '#80FF0000');
    expect(picked.last, const Color(0xFFFF0000));
  }, variant: ios);

  testWidgets('the opacity slider sets the alpha', (t) async {
    shaderEnv();
    _tall(t);
    final picked = <Color>[];
    await t.pumpWidget(appHost(_Harness(onChanged: picked.add)));
    await _open(t);
    final slider = t.getRect(find.byType(ColorChannelSlider));
    await t.tapAt(Offset(slider.left + slider.width / 2, slider.center.dy));
    await t.pumpAndSettle();
    expect(picked, isNotEmpty);
    expect(picked.last.a, closeTo(0.5, 0.05));
    expect(picked.last.withValues(alpha: 1), _blue);
  }, variant: ios);

  testWidgets('the Sliders page sets each channel', (t) async {
    shaderEnv();
    _tall(t);
    final picked = <Color>[];
    await t.pumpWidget(appHost(_Harness(onChanged: picked.add)));
    await _open(t);
    await _sliders(t);
    expect(find.text('RED'), findsOneWidget);
    expect(find.byType(ColorChannelSlider), findsNWidgets(4));
    // Red, green, blue fields read the colour (#007AFF).
    final fields = _field(ColorPickerMetrics.fieldWidth);
    expect(
      [
        for (final e in fields.evaluate())
          (e.widget as EditableText).controller.text,
      ],
      ['0', '122', '255', '100%'],
    );
    await t.enterText(fields.first, '255');
    await t.pumpAndSettle();
    expect(picked.last, const Color(0xFFFF7AFF));
    // The red slider's end sets 255 too; its start 0.
    final red = t.getRect(find.byType(ColorChannelSlider).first);
    await t.tapAt(Offset(red.left + 1, red.center.dy));
    await t.pumpAndSettle();
    expect(picked.last, const Color(0xFF007AFF));
  }, variant: ios);

  testWidgets("the sheet is UIColorPickerViewController's height, no "
      'grabber', (t) async {
    shaderEnv();
    _tall(t);
    await t.pumpWidget(appHost(const _Harness()));
    await _open(t);
    final sheet = t.getRect(find.byType(GlassSheet));
    final panel = t.getRect(find.byType(GlassColorPickerPanel));
    // No grabber: the content starts at the sheet's top edge, and the
    // sheet floats 8 pt above the screen's bottom.
    expect(panel.top, moreOrLessEquals(sheet.top));
    expect(panel.height, moreOrLessEquals(ColorPickerMetrics.sheetHeight));
    expect(panel.bottom, moreOrLessEquals(1400 - 8));
  }, variant: ios);

  testWidgets('null onChanged disables the row', (t) async {
    shaderEnv();
    await t.pumpWidget(appHost(const _Harness(enabled: false)));
    await _open(t);
    expect(find.byType(GlassColorPickerPanel), findsNothing);
    expect(
      t.getSemantics(find.byType(GlassColorPicker)),
      isSemantics(isButton: true, isEnabled: false),
    );
  }, variant: ios);

  testWidgets('semantics: one button with the label and the hex value', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(appHost(const _Harness(semanticLabel: 'Accent colour')));
    expect(
      t.getSemantics(find.byType(GlassColorPicker)),
      isSemantics(
        label: 'Accent colour',
        value: '#007AFF',
        isButton: true,
        isEnabled: true,
      ),
    );
  }, variant: ios);

  testWidgets('RTL: the swatch sits at the start, the label after it', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: Center(child: _Harness())),
        ),
      ),
    );
    final label = t.getRect(find.text('Accent'));
    final swatch = t.getRect(find.byType(ColorSwatchDot));
    expect(swatch.right, lessThan(label.left));
  }, variant: ios);

  testWidgets('LTR: the swatch sits at the end', (t) async {
    shaderEnv();
    await t.pumpWidget(appHost(const _Harness()));
    final label = t.getRect(find.text('Accent'));
    final swatch = t.getRect(find.byType(ColorSwatchDot));
    expect(swatch.left, greaterThan(label.right));
  }, variant: ios);
}

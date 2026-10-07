import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_colors.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

const _items = [
  GlassPickerItem(value: 'a', label: 'Apple'),
  GlassPickerItem(value: 'b', label: 'Banana'),
  GlassPickerItem(value: 'c', label: 'Cherry'),
  GlassPickerItem(value: 'd', label: 'Date'),
];

class _Harness extends StatefulWidget {
  const _Harness({this.enabled = true, this.semanticLabel, this.calls});

  final bool enabled;
  final String? semanticLabel;
  final List<String>? calls;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  String selected = 'a';

  void select(String v) => setState(() => selected = v);

  @override
  Widget build(BuildContext context) => GlassWheelPicker<String>(
    items: _items,
    selected: selected,
    semanticLabel: widget.semanticLabel,
    onChanged: widget.enabled
        ? (v) {
            widget.calls?.add(v);
            setState(() => selected = v);
          }
        : null,
  );
}

_HarnessState _state(WidgetTester t) =>
    t.state<_HarnessState>(find.byType(_Harness));

FixedExtentScrollController _controller(WidgetTester t) =>
    t.widget<ListWheelScrollView>(find.byType(ListWheelScrollView)).controller!
        as FixedExtentScrollController;

/// Drags the wheel up by [rows] rows and lets it settle. The extra 0.4 row
/// keeps the drag past the nearest-row midpoint whether or not the host
/// swallows the touch slop (plainHost does; MaterialApp does not).
Future<void> _scroll(WidgetTester t, int rows) async {
  await t.drag(
    find.byType(ListWheelScrollView),
    Offset(0, -(rows + 0.4) * WheelPickerMetrics.itemExtent),
  );
  await t.pumpAndSettle();
}

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('renders every item on glass at 320 x 216', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness()));
    for (final i in _items) {
      expect(find.text(i.label), findsOneWidget);
    }
    expect(
      t.getSize(find.byType(GlassWheelPicker<String>)),
      const Size(WheelPickerMetrics.width, WheelPickerMetrics.height),
    );
    // The surface and the clear selection band.
    expect(find.byType(LiquidGlass), findsNWidgets(2));
    expect(find.byType(CupertinoPicker), findsNothing);
  }, variant: ios);

  testWidgets('dragging changes the selection, once per change, with a click', (
    t,
  ) async {
    shaderEnv();
    final calls = <String>[];
    final haptics = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await t.pumpWidget(plainHost(_Harness(calls: calls)));
    await _scroll(t, 1);
    expect(calls, ['b']);
    expect(_state(t).selected, 'b');
    expect(haptics, ['HapticFeedbackType.selectionClick']);
    await _scroll(t, 1);
    await _scroll(t, 1);
    expect(calls, ['b', 'c', 'd']);
    expect(haptics, hasLength(3));
    expect(_controller(t).selectedItem, 3);
  }, variant: ios);

  testWidgets('null onChanged disables: no scrolling, dim labels', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness(enabled: false)));
    // Nothing under the finger: the wheel ignores pointers.
    await t.drag(
      find.byType(ListWheelScrollView),
      const Offset(0, -WheelPickerMetrics.itemExtent * 2),
      warnIfMissed: false,
    );
    await t.pumpAndSettle();
    expect(_state(t).selected, 'a');
    expect(_controller(t).selectedItem, 0);
    final style = t.widget<Text>(find.text('Apple')).style!;
    expect(
      style.color,
      CupertinoDynamicColor.resolve(
        GlassColors.tertiaryLabel,
        t.element(find.text('Apple')),
      ),
    );
    expect(
      t.getSemantics(find.byType(GlassWheelPicker<String>)),
      matchesSemantics(value: 'Apple', hasEnabledState: true, isEnabled: false),
    );
  }, variant: ios);

  testWidgets('a parent-driven selection jumps the wheel', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness()));
    _state(t).select('d');
    await t.pump();
    expect(_controller(t).selectedItem, 3);
    // No onChanged echo and no animation: settled in the one frame.
    expect(t.hasRunningAnimations, isFalse);
  }, variant: ios);

  testWidgets('one semantics node: label, value, increase and decrease', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness(semanticLabel: 'Fruit')));
    final finder = find.byType(GlassWheelPicker<String>);
    expect(
      t.getSemantics(finder),
      matchesSemantics(
        label: 'Fruit',
        value: 'Apple',
        increasedValue: 'Banana',
        hasEnabledState: true,
        isEnabled: true,
        hasIncreaseAction: true,
        hasDecreaseAction: false,
      ),
    );
    expect(find.bySemanticsLabel('Banana'), findsNothing);
    t.semantics.performAction(
      find.semantics.byLabel('Fruit'),
      SemanticsAction.increase,
    );
    await t.pumpAndSettle();
    expect(_state(t).selected, 'b');
    expect(
      t.getSemantics(finder),
      matchesSemantics(
        label: 'Fruit',
        value: 'Banana',
        increasedValue: 'Cherry',
        decreasedValue: 'Apple',
        hasEnabledState: true,
        isEnabled: true,
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );
  }, variant: ios);

  testWidgets('right to left: same size, labels centred', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(const _Harness(), direction: TextDirection.rtl),
    );
    final picker = find.byType(GlassWheelPicker<String>);
    expect(
      t.getSize(picker),
      const Size(WheelPickerMetrics.width, WheelPickerMetrics.height),
    );
    expect(t.getCenter(find.text('Apple')).dx, t.getCenter(picker).dx);
    await _scroll(t, 1);
    expect(_state(t).selected, 'b');
  }, variant: ios);

  testWidgets('Material: a ListWheelScrollView, no CupertinoPicker or glass', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(appHost(const _Harness()));
    expect(find.byType(ListWheelScrollView), findsOneWidget);
    expect(find.byType(CupertinoPicker), findsNothing);
    expect(find.byType(LiquidGlass), findsNothing);
    final scheme = Theme.of(t.element(find.byType(_Harness))).colorScheme;
    expect(
      t
          .widgetList<Material>(find.byType(Material))
          .any((m) => m.color == scheme.surfaceContainerHigh),
      isTrue,
    );
    expect(
      t
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .any(
            (d) =>
                (d.decoration as BoxDecoration).color ==
                scheme.primaryContainer,
          ),
      isTrue,
    );
    await _scroll(t, 1);
    expect(_state(t).selected, 'b');
  }, variant: android);
}

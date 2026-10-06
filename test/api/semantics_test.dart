import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart' show RendererBinding;
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hosts.dart';

/// Semantics nodes with a tap action under [root] (inclusive).
///
/// A node merged into its parent is part of that parent's node, not one of
/// its own, so it (and its subtree) is skipped.
int tappable(SemanticsNode root) {
  var n = 0;
  bool visit(SemanticsNode node) {
    if (node.isMergedIntoParent) return true;
    final data = node.getSemanticsData();
    if (data.hasAction(SemanticsAction.tap)) n++;
    node.visitChildren(visit);
    return true;
  }

  visit(root);
  return n;
}

/// The owner of the semantics tree (needs `ensureSemantics` first).
SemanticsOwner _owner(WidgetTester t) =>
    RendererBinding.instance.renderViews.first.owner!.semanticsOwner!;

/// The semantics tree's root node (needs `ensureSemantics` and a pump).
SemanticsNode _rootNode(WidgetTester t) => _owner(t).rootSemanticsNode!;

/// Performs the dismiss action on the node [finder] locates, then settles.
Future<void> _dismiss(WidgetTester t, Finder finder) async {
  final node = t.getSemantics(finder);
  _owner(t).performAction(node.id, SemanticsAction.dismiss);
  await t.pumpAndSettle();
}

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  group('button', () {
    testWidgets('is one node carrying label, role, state and tap', (t) async {
      shaderEnv();
      final semantics = t.ensureSemantics();
      await t.pumpWidget(
        appHost(GlassButton(onPressed: () {}, child: const Text('Save'))),
      );
      expect(find.bySemanticsLabel('Save'), findsOneWidget);
      expect(
        t.getSemantics(find.bySemanticsLabel('Save')),
        isSemantics(
          label: 'Save',
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      expect(tappable(_rootNode(t)), 1);
      semantics.dispose();
    }, variant: ios);

    testWidgets('a semanticLabel replaces, not doubles, the visible one', (
      t,
    ) async {
      shaderEnv();
      final semantics = t.ensureSemantics();
      await t.pumpWidget(
        appHost(
          GlassButton(
            onPressed: () {},
            semanticLabel: 'Store',
            child: const Text('Save'),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Store'), findsOneWidget);
      expect(t.getSemantics(find.bySemanticsLabel('Store')).label, 'Store');
      expect(find.bySemanticsLabel('Save'), findsNothing);
      expect(tappable(_rootNode(t)), 1);
      semantics.dispose();
    }, variant: ios);

    testWidgets('an icon-only button carries its semanticLabel', (t) async {
      shaderEnv();
      final semantics = t.ensureSemantics();
      await t.pumpWidget(
        appHost(
          GlassButton.icon(
            onPressed: () {},
            icon: CupertinoIcons.add,
            semanticLabel: 'Add',
          ),
        ),
      );
      expect(
        t.getSemantics(find.bySemanticsLabel('Add')),
        isSemantics(label: 'Add', isButton: true, hasTapAction: true),
      );
      semantics.dispose();
    }, variant: ios);

    testWidgets('a disabled button is still a disabled button', (t) async {
      shaderEnv();
      final semantics = t.ensureSemantics();
      await t.pumpWidget(
        appHost(const GlassButton(onPressed: null, child: Text('Save'))),
      );
      expect(
        t.getSemantics(find.bySemanticsLabel('Save')),
        isSemantics(
          label: 'Save',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      semantics.dispose();
    }, variant: ios);

    testWidgets('Material: a semanticLabel replaces the visible one too', (
      t,
    ) async {
      shaderEnv();
      final semantics = t.ensureSemantics();
      await t.pumpWidget(
        appHost(
          GlassButton(
            onPressed: () {},
            semanticLabel: 'Store',
            child: const Text('Save'),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Store'), findsOneWidget);
      expect(t.getSemantics(find.bySemanticsLabel('Store')).label, 'Store');
      expect(find.bySemanticsLabel('Save'), findsNothing);
      semantics.dispose();
    }, variant: android);
  });

  group('controls', () {
    testWidgets('GlassToggle is one node with its state and tap', (t) async {
      shaderEnv();
      final semantics = t.ensureSemantics();
      await t.pumpWidget(appHost(GlassToggle(value: true, onChanged: (_) {})));
      expect(
        t.getSemantics(find.byType(GlassToggle)),
        isSemantics(
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      expect(tappable(_rootNode(t)), 1);
      semantics.dispose();
    }, variant: ios);

    testWidgets('GlassSlider reports its value and both actions', (t) async {
      shaderEnv();
      final semantics = t.ensureSemantics();
      await t.pumpWidget(appHost(GlassSlider(value: 0.5, onChanged: (_) {})));
      expect(
        t.getSemantics(find.byType(GlassSlider)),
        isSemantics(
          isSlider: true,
          value: '50%',
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      semantics.dispose();
    }, variant: ios);

    testWidgets('GlassSegmentedControl: one labelled button per segment', (
      t,
    ) async {
      shaderEnv();
      final semantics = t.ensureSemantics();
      await t.pumpWidget(
        appHost(
          GlassSegmentedControl<int>(
            segments: const [
              GlassSegment(value: 0, label: Text('A')),
              GlassSegment(value: 1, label: Text('B'), semanticLabel: 'Bee'),
            ],
            selected: 0,
            onChanged: (_) {},
          ),
        ),
      );
      expect(
        t.getSemantics(find.bySemanticsLabel('A')),
        isSemantics(
          label: 'A',
          isSelected: true,
          hasSelectedState: true,
          isButton: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      final bee = t.getSemantics(find.bySemanticsLabel('Bee'));
      expect(bee.label, 'Bee');
      expect(
        bee,
        isSemantics(
          isSelected: false,
          hasSelectedState: true,
          isButton: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      expect(find.bySemanticsLabel('B'), findsNothing);
      expect(tappable(_rootNode(t)), 2);
      semantics.dispose();
    }, variant: ios);
  });

  group('stepper', () {
    testWidgets('minus and plus are labelled, enabled buttons', (t) async {
      shaderEnv();
      final semantics = t.ensureSemantics();
      await t.pumpWidget(appHost(GlassStepper(value: 3, onChanged: (_) {})));
      for (final label in const ['Decrement', 'Increment']) {
        expect(
          t.getSemantics(find.bySemanticsLabel(label)),
          isSemantics(
            label: label,
            isButton: true,
            hasTapAction: true,
            hasEnabledState: true,
            isEnabled: true,
          ),
        );
      }
      expect(tappable(_rootNode(t)), 2);
      semantics.dispose();
    }, variant: ios);

    testWidgets('at the min the decrement half is disabled without a tap', (
      t,
    ) async {
      shaderEnv();
      final semantics = t.ensureSemantics();
      await t.pumpWidget(appHost(GlassStepper(value: 0, onChanged: (_) {})));
      expect(
        t.getSemantics(find.bySemanticsLabel('Decrement')),
        isSemantics(
          label: 'Decrement',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      semantics.dispose();
    }, variant: ios);
  });

  group('picker', () {
    testWidgets('closed: one button labelled with its choice', (t) async {
      shaderEnv();
      final semantics = t.ensureSemantics();
      await t.pumpWidget(
        appHost(
          GlassPicker<int>(
            items: const [
              GlassPickerItem(value: 0, label: 'Day'),
              GlassPickerItem(value: 1, label: 'Week'),
            ],
            selected: 0,
            onChanged: (_) {},
          ),
        ),
      );
      final node = t.getSemantics(find.bySemanticsLabel('Day'));
      expect(node.value, isEmpty);
      expect(
        node,
        isSemantics(label: 'Day', isButton: true, hasTapAction: true),
      );
      expect(tappable(_rootNode(t)), 1);
      semantics.dispose();
    }, variant: ios);

    testWidgets('a semanticLabel moves the choice into the value', (t) async {
      shaderEnv();
      final semantics = t.ensureSemantics();
      await t.pumpWidget(
        appHost(
          GlassPicker<int>(
            items: const [
              GlassPickerItem(value: 0, label: 'Day'),
              GlassPickerItem(value: 1, label: 'Week'),
            ],
            selected: 0,
            onChanged: (_) {},
            semanticLabel: 'Period',
          ),
        ),
      );
      expect(
        t.getSemantics(find.bySemanticsLabel('Period')),
        isSemantics(
          label: 'Period',
          value: 'Day',
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(find.bySemanticsLabel('Day'), findsNothing);
      semantics.dispose();
    }, variant: ios);

    testWidgets('open: checked rows and a dismissable barrier', (t) async {
      shaderEnv();
      final semantics = t.ensureSemantics();
      await t.pumpWidget(
        appHost(
          GlassPicker<int>(
            items: const [
              GlassPickerItem(value: 0, label: 'Day'),
              GlassPickerItem(value: 1, label: 'Week'),
            ],
            selected: 0,
            onChanged: (_) {},
          ),
        ),
      );
      await t.tap(find.byType(GlassPicker<int>));
      await t.pumpAndSettle();
      expect(
        t.getSemantics(find.bySemanticsLabel('Day')),
        isSemantics(
          label: 'Day',
          isSelected: true,
          hasSelectedState: true,
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(
        t.getSemantics(find.bySemanticsLabel('Week')),
        isSemantics(
          label: 'Week',
          isSelected: false,
          hasSelectedState: true,
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(
        t.getSemantics(find.bySemanticsLabel('Dismiss')),
        isSemantics(hasDismissAction: true, hasTapAction: true),
      );
      await _dismiss(t, find.bySemanticsLabel('Dismiss'));
      expect(find.bySemanticsLabel('Week'), findsNothing);
      semantics.dispose();
    }, variant: ios);
  });

  group('menu', () {
    testWidgets('labelled items, a disabled one, and a dismiss barrier', (
      t,
    ) async {
      shaderEnv();
      final semantics = t.ensureSemantics();
      await t.pumpWidget(
        appHost(
          GlassMenuButton(
            icon: CupertinoIcons.ellipsis,
            semanticLabel: 'More',
            items: [
              GlassMenuItem(
                label: 'Copy',
                semanticLabel: 'Copy link',
                onSelected: () {},
              ),
              const GlassMenuItem(label: 'Delete', onSelected: null),
            ],
          ),
        ),
      );
      expect(
        t.getSemantics(find.bySemanticsLabel('More')),
        isSemantics(label: 'More', isButton: true, hasTapAction: true),
      );
      await t.tap(find.byType(GlassMenuButton));
      await t.pumpAndSettle();
      expect(
        t.getSemantics(find.bySemanticsLabel('Copy link')),
        isSemantics(
          label: 'Copy link',
          isButton: true,
          hasTapAction: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      expect(find.bySemanticsLabel(RegExp(r'^Copy$')), findsNothing);
      expect(
        t.getSemantics(find.bySemanticsLabel('Delete')),
        isSemantics(
          label: 'Delete',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      expect(
        t.getSemantics(find.bySemanticsLabel('Dismiss')),
        isSemantics(hasDismissAction: true, hasTapAction: true),
      );
      semantics.dispose();
    }, variant: ios);
  });

  group('popover', () {
    testWidgets('scopes and names its route, and can be dismissed', (t) async {
      shaderEnv();
      final semantics = t.ensureSemantics();
      await t.pumpWidget(
        appHost(
          Builder(
            builder: (context) => GlassButton(
              onPressed: () => showGlassPopover<void>(
                context: context,
                semanticLabel: 'Info',
                builder: (_) => const Text('Hello'),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      expect(
        t.getSemantics(find.bySemanticsLabel('Info')),
        isSemantics(label: 'Info', scopesRoute: true, namesRoute: true),
      );
      expect(find.bySemanticsLabel('Hello'), findsOneWidget);
      expect(
        t.getSemantics(find.bySemanticsLabel('Dismiss')),
        isSemantics(hasDismissAction: true, hasTapAction: true),
      );
      await _dismiss(t, find.bySemanticsLabel('Dismiss'));
      expect(find.text('Hello'), findsNothing);
      semantics.dispose();
    }, variant: ios);
  });

  group('search', () {
    testWidgets('a text field labelled by its placeholder', (t) async {
      shaderEnv();
      final semantics = t.ensureSemantics();
      await t.pumpWidget(appHost(const GlassSearchField()));
      expect(find.bySemanticsLabel('Search'), findsOneWidget);
      expect(
        t.getSemantics(find.bySemanticsLabel('Search')),
        isSemantics(
          label: 'Search',
          isTextField: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      semantics.dispose();
    }, variant: ios);

    testWidgets('a semanticLabel precedes the placeholder', (t) async {
      shaderEnv();
      final semantics = t.ensureSemantics();
      await t.pumpWidget(
        appHost(const GlassSearchField(semanticLabel: 'Find songs')),
      );
      final node = t.getSemantics(find.byType(CupertinoTextField));
      expect(node.label, startsWith('Find songs'));
      expect(node.getSemanticsData().flagsCollection.isTextField, isTrue);
      semantics.dispose();
    }, variant: ios);

    testWidgets('with text: label and value separate, Clear its own node', (
      t,
    ) async {
      shaderEnv();
      final semantics = t.ensureSemantics();
      final controller = TextEditingController(text: 'abc');
      addTearDown(controller.dispose);
      await t.pumpWidget(
        appHost(
          GlassSearchField(semanticLabel: 'Find songs', controller: controller),
        ),
      );
      final field = t.getSemantics(find.byType(CupertinoTextField));
      expect(field.label, 'Find songs');
      expect(field, isSemantics(isTextField: true, value: 'abc'));
      final clear = t.getSemantics(find.bySemanticsLabel('Clear'));
      expect(
        clear,
        isSemantics(label: 'Clear', isButton: true, hasTapAction: true),
      );
      expect(field.id, isNot(clear.id));
      expect(field.label.contains('Clear'), isFalse);
      semantics.dispose();
    }, variant: ios);
  });

  group('tab_bar', () {
    testWidgets('tabs are selected buttons; the search tab taps', (t) async {
      shaderEnv();
      final semantics = t.ensureSemantics();
      var searched = 0;
      await t.pumpWidget(
        appHost(
          GlassTabBar(
            items: const [
              GlassTabBarItem(icon: CupertinoIcons.home, label: 'Home'),
              GlassTabBarItem(icon: CupertinoIcons.gear, label: 'Settings'),
            ],
            selectedIndex: 0,
            onSelected: (_) {},
            onSearch: () => searched++,
          ),
        ),
      );
      expect(
        t.getSemantics(find.bySemanticsLabel('Home')),
        isSemantics(
          label: 'Home',
          isSelected: true,
          hasSelectedState: true,
          isButton: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      expect(
        t.getSemantics(find.bySemanticsLabel('Settings')),
        isSemantics(
          label: 'Settings',
          isSelected: false,
          hasSelectedState: true,
          isButton: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      final search = t.getSemantics(find.bySemanticsLabel('Search'));
      expect(
        search,
        isSemantics(label: 'Search', isButton: true, hasTapAction: true),
      );
      _owner(t).performAction(search.id, SemanticsAction.tap);
      await t.pump();
      expect(searched, 1);
      semantics.dispose();
    }, variant: ios);
  });

  group('toolbar', () {
    testWidgets('each item keeps its own labelled button node', (t) async {
      shaderEnv();
      final semantics = t.ensureSemantics();
      await t.pumpWidget(
        appHost(
          GlassToolbar(
            children: [
              GlassButton.icon(
                onPressed: () {},
                icon: CupertinoIcons.add,
                semanticLabel: 'Add',
              ),
              GlassButton.icon(
                onPressed: () {},
                icon: CupertinoIcons.share,
                semanticLabel: 'Share',
              ),
            ],
          ),
        ),
      );
      for (final label in const ['Add', 'Share']) {
        expect(
          t.getSemantics(find.bySemanticsLabel(label)),
          isSemantics(label: label, isButton: true, hasTapAction: true),
        );
      }
      expect(tappable(_rootNode(t)), 2);
      semantics.dispose();
    }, variant: ios);
  });
}

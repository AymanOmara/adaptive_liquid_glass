import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('activate and cancel notify', () {
    final controller = GlassSearchController();
    var notified = 0;
    controller.addListener(() => notified++);
    controller.activate();
    expect(controller.isActive, true);
    expect(notified, 1);
    controller.cancel();
    expect(controller.isActive, false);
    expect(notified, 2);
    controller.dispose();
  });

  test('cancel clears the text but keeps the scope', () {
    final controller = GlassSearchController()
      ..text = 'glass'
      ..scopeIndex = 1
      ..activate()
      ..cancel();
    expect(controller.text, '');
    expect(controller.scopeIndex, 1);
    controller.dispose();
  });

  test('scopeIndex notifies only on change', () {
    final controller = GlassSearchController();
    var notified = 0;
    controller.addListener(() => notified++);
    controller.scopeIndex = 0;
    expect(notified, 0);
    controller.scopeIndex = 2;
    expect(controller.scopeIndex, 2);
    expect(notified, 1);
    controller.dispose();
  });

  test('the text setter updates the text controller, selection at end', () {
    final controller = GlassSearchController()..text = 'query';
    expect(controller.textController.text, 'query');
    expect(controller.textController.selection.isCollapsed, true);
    expect(controller.textController.selection.baseOffset, 'query'.length);
    controller.dispose();
  });

  test('edits through the text controller notify', () {
    final controller = GlassSearchController();
    var notified = 0;
    controller.addListener(() => notified++);
    controller.textController.text = 'typed';
    expect(notified, 1);
    expect(controller.text, 'typed');
    controller.dispose();
  });
}

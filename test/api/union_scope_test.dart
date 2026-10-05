import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/group/glass_member.dart';
import 'package:adaptive_liquid_glass/src/group/glass_union_scope.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hosts.dart';

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('glass below a GlassUnionScope takes its id; its own wins', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        GlassGroup(
          child: GlassUnionScope(
            id: 'actions',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 30, height: 30).glassEffect(),
                const SizedBox(
                  width: 30,
                  height: 30,
                ).glassEffect(unionId: 'mine'),
              ],
            ),
          ),
        ),
      ),
    );
    final members = t
        .widgetList<GlassMember>(find.byType(GlassMember))
        .toList();
    expect(members[0].unionId, 'actions');
    expect(members[1].unionId, 'mine');
  }, variant: ios);
}

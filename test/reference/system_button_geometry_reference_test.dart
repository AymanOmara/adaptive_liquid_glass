import 'dart:convert';
import 'dart:io';

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/button/system_button_metrics.dart';
import 'package:adaptive_liquid_glass/src/button/system_style_button.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

void main() {
  final reference =
      jsonDecode(
            File(
              'tool/reference/system_button_geometry.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final styles = reference['styles'] as Map<String, dynamic>;
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  for (final style in [
    GlassButtonStyle.bordered,
    GlassButtonStyle.borderedProminent,
    GlassButtonStyle.borderless,
    GlassButtonStyle.plain,
  ]) {
    final rows = styles[style.name] as Map<String, dynamic>;
    for (final size in GlassControlSize.values) {
      final measured = rows[size.name] as Map<String, dynamic>;
      testWidgets(
        '${style.name} ${size.name}: native layout padding and size',
        (t) async {
          shaderEnv();
          await t.pumpWidget(
            plainHost(
              GlassButton(
                style: style,
                size: size,
                onPressed: () {},
                child: const Text('Button'),
              ),
            ),
          );
          final labelSize = t.getSize(find.text('Button'));
          final buttonSize = t.getSize(find.byType(GlassButton));
          expect(
            (buttonSize.width - labelSize.width) / 2,
            moreOrLessEquals(
              (measured['padding'] as num).toDouble(),
              epsilon: 0.01,
            ),
          );
          final bordered =
              style == GlassButtonStyle.bordered ||
              style == GlassButtonStyle.borderedProminent;
          if (bordered) {
            expect(
              buttonSize.height,
              moreOrLessEquals(
                (measured['button'][1] as num).toDouble(),
                epsilon: 0.01,
              ),
            );
          } else {
            expect(buttonSize, labelSize);
          }
          final m = SystemButtonMetrics.forSize(size, style: style);
          // Plain's mini/small labels are the regular body size; the other
          // styles use the smaller font. Native label widths verify this
          // independently of Flutter test fonts (which are Ahem).
          final sameAsRegular =
              measured['label'][0] == rows['regular']['label'][0];
          expect(m.fontSize, sameAsRegular ? 17 : 15);
          expect(
            DefaultTextStyle.of(t.element(find.text('Button'))).style.fontSize,
            m.fontSize,
          );
          if (bordered) {
            await t.pumpWidget(
              plainHost(
                GlassButton.icon(
                  style: style,
                  size: size,
                  onPressed: () {},
                  icon: CupertinoIcons.add,
                ),
              ),
            );
            final actual = t.getSize(find.byType(SystemStyleButton));
            expect(
              actual.width,
              moreOrLessEquals(
                (measured['iconButton'][0] as num).toDouble(),
                epsilon: 0.01,
              ),
            );
            expect(
              actual.height,
              moreOrLessEquals(
                (measured['iconButton'][1] as num).toDouble(),
                epsilon: 0.01,
              ),
            );
          }
        },
        variant: ios,
      );
    }
  }
}

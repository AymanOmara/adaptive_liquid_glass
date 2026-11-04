import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));

  Widget hostFor(Widget child) =>
      defaultTargetPlatform == TargetPlatform.android
      ? appHost(child)
      : plainHost(child);

  for (final style in [GlassButtonStyle.glass, GlassButtonStyle.bordered]) {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      final variant = TargetPlatformVariant.only(platform);

      testWidgets('$style $platform: loadingValue shows a determinate ring', (
        tester,
      ) async {
        shaderEnv();
        await tester.pumpWidget(
          hostFor(
            GlassButton(
              onPressed: () {},
              loading: true,
              loadingValue: 0.4,
              style: style,
              child: const Text('Go'),
            ),
          ),
        );
        if (platform == TargetPlatform.android) {
          expect(find.byType(CupertinoActivityIndicator), findsNothing);
          final ring = find.byType(CircularProgressIndicator);
          expect(ring, findsOneWidget);
          expect(tester.widget<CircularProgressIndicator>(ring).value, 0.4);
        } else {
          expect(find.byType(CircularProgressIndicator), findsNothing);
          final ring = find.byType(CupertinoActivityIndicator);
          expect(ring, findsOneWidget);
          expect(tester.widget<CupertinoActivityIndicator>(ring).progress, 0.4);
        }
      }, variant: variant);

      testWidgets('$style $platform: loadingValue is normalised', (
        tester,
      ) async {
        shaderEnv();
        double? shown() => platform == TargetPlatform.android
            ? tester
                  .widget<CircularProgressIndicator>(
                    find.byType(CircularProgressIndicator),
                  )
                  .value
            : tester
                  .widget<CupertinoActivityIndicator>(
                    find.byType(CupertinoActivityIndicator),
                  )
                  .progress;
        for (final (input, expected) in <(double, double?)>[
          (-1, 0),
          (2, 1),
          (double.nan, null),
          (double.infinity, null),
        ]) {
          await tester.pumpWidget(
            hostFor(
              GlassButton(
                onPressed: () {},
                loading: true,
                loadingValue: input,
                style: style,
                child: const Text('Go'),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          if (expected == null) {
            // Indeterminate: Material has no value, Cupertino spins fully.
            if (platform == TargetPlatform.android) {
              expect(shown(), isNull);
            } else {
              expect(
                find.byWidgetPredicate(
                  (w) => w is CupertinoActivityIndicator && w.animating,
                ),
                findsOneWidget,
              );
            }
          } else {
            expect(shown(), expected);
          }
        }
      }, variant: variant);

      testWidgets(
        '$style $platform: without onLoadingPressed taps do nothing',
        (tester) async {
          shaderEnv();
          final handle = tester.ensureSemantics();
          var pressed = 0;
          await tester.pumpWidget(
            hostFor(
              GlassButton(
                onPressed: () => pressed++,
                loading: true,
                style: style,
                child: const Text('Go'),
              ),
            ),
          );
          await tester.tap(find.byType(GlassButton));
          expect(pressed, 0);
          expect(
            tester.getSemantics(find.byType(GlassButton)),
            matchesSemantics(
              isButton: true,
              hasEnabledState: true,
              isEnabled: false,
              label: 'Go',
              value: 'loading',
            ),
          );
          handle.dispose();
        },
        variant: variant,
      );

      testWidgets('$style $platform: onLoadingPressed fires while loading', (
        tester,
      ) async {
        shaderEnv();
        final handle = tester.ensureSemantics();
        var pressed = 0, cancelled = 0;
        await tester.pumpWidget(
          hostFor(
            GlassButton(
              onPressed: () => pressed++,
              onLoadingPressed: () => cancelled++,
              loading: true,
              loadingLabel: 'Cancel import',
              style: style,
              child: const Text('Go'),
            ),
          ),
        );
        await tester.tap(find.byType(GlassButton));
        expect((pressed, cancelled), (0, 1));
        expect(
          tester.getSemantics(find.byType(GlassButton)),
          matchesSemantics(
            isButton: true,
            isEnabled: true,
            hasEnabledState: true,
            hasTapAction: true,
            // Only the Material button exposes a focus action.
            hasFocusAction: platform == TargetPlatform.android,
            isFocusable: true,
            label: 'Go',
            value: 'Cancel import',
          ),
        );
        handle.dispose();
      }, variant: variant);
    }
  }
}

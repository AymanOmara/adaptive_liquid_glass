import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/navigation/progressive_blur.dart';
import 'package:adaptive_liquid_glass/src/navigation/progressive_blur_uniforms.dart';
import 'package:adaptive_liquid_glass/src/navigation/scroll_edge.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _page({
  GlassScrollEdgeStyle? style,
  TextDirection dir = TextDirection.ltr,
}) => MaterialApp(
  builder: (c, child) => Directionality(textDirection: dir, child: child!),
  home: Scaffold(
    extendBodyBehindAppBar: true,
    appBar: style == null
        ? const GlassNavigationBar(title: Text('Inbox'))
        : GlassNavigationBar(
            title: const Text('Inbox'),
            scrollEdgeStyle: style,
          ),
    body: ListView(
      children: [
        for (var i = 0; i < 50; i++)
          SizedBox(height: 44, child: Text('Row $i')),
      ],
    ),
  ),
);

GlassScrollEdge _edge(WidgetTester t) =>
    t.widget<GlassScrollEdge>(find.byType(GlassScrollEdge));

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('the default stays the uniform blur', (t) async {
    shaderEnv();
    await t.pumpWidget(_page());
    expect(_edge(t).style, GlassScrollEdgeStyle.uniform);
    expect(find.byType(ProgressiveBlur), findsNothing);
  }, variant: ios);

  testWidgets('the bar passes the progressive style to its edge', (t) async {
    shaderEnv();
    await t.pumpWidget(_page(style: GlassScrollEdgeStyle.progressive));
    expect(_edge(t).style, GlassScrollEdgeStyle.progressive);
    expect(find.byType(ProgressiveBlur), findsOneWidget);
  }, variant: ios);

  testWidgets('the large-title bar passes it too', (t) async {
    shaderEnv();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              const SliverGlassNavigationBar(
                largeTitle: Text('Inbox'),
                scrollEdgeStyle: GlassScrollEdgeStyle.progressive,
              ),
              SliverList.list(
                children: [
                  for (var i = 0; i < 50; i++)
                    SizedBox(height: 44, child: Text('Row $i')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    expect(_edge(t).style, GlassScrollEdgeStyle.progressive);
  }, variant: ios);

  testWidgets('without its shader the progressive edge is the uniform blur', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const GlassScrollEdge(
          visible: true,
          height: 100,
          style: GlassScrollEdgeStyle.progressive,
        ),
      ),
    );
    // The fallback: one even blur over the top 80%.
    final blur = find.byType(BackdropFilter);
    expect(blur, findsOneWidget);
    expect(t.getSize(blur).height, moreOrLessEquals(80));
  }, variant: ios);

  testWidgets('RTL: the fallback still spans the edge', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const SizedBox(
          width: 300,
          child: GlassScrollEdge(
            visible: true,
            height: 100,
            style: GlassScrollEdgeStyle.progressive,
          ),
        ),
        direction: TextDirection.rtl,
      ),
    );
    expect(t.getSize(find.byType(BackdropFilter)).width, 300);
  }, variant: ios);

  testWidgets('never blurs on the native path', (t) async {
    GlassPlatform.instance.debugEnvironment = const GlassEnvironment(
      platform: TargetPlatform.iOS,
      iosMajorVersion: 26,
      reduceTransparency: false,
      shaderSupported: true,
    );
    await t.pumpWidget(
      plainHost(
        const GlassScrollEdge(
          visible: true,
          height: 100,
          style: GlassScrollEdgeStyle.progressive,
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(ProgressiveBlur), findsNothing);
  }, variant: ios);

  testWidgets('Material: an AppBar, no scroll edge', (t) async {
    shaderEnv();
    await t.pumpWidget(_page(style: GlassScrollEdgeStyle.progressive));
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(GlassScrollEdge), findsNothing);
  }, variant: android);

  test('uniforms are in screen device px', () {
    expect(
      progressiveBlurUniforms(
        origin: const Offset(0, 10),
        size: const Size(390, 100),
        devicePixelRatio: 3,
        maxSigma: 8,
        falloff: 1.2,
        axis: 1,
      ),
      [24, 1.2, 1, 0, 30, 1170, 300],
    );
  });
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;

import '../core/effective_glass_mode.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import 'form_metrics.dart';
import 'glass_list_section.dart';
import 'list_section_scope.dart';

/// iOS 26's form, like SwiftUI's `Form`: [GlassListSection]s stacked with
/// grouped insets on the grouped page background, scrolling, and keeping
/// a focused field above the keyboard.
///
/// ```dart
/// GlassForm(
///   children: [
///     GlassListSection(
///       header: const Text('Account'),
///       footer: const Text('Used to sign in on your devices.'),
///       children: [
///         GlassListTile(
///           title: CupertinoTextField.borderless(
///             placeholder: 'Name',
///             controller: name,
///             padding: EdgeInsets.zero,
///           ),
///         ),
///       ],
///     ),
///     GlassListSection(
///       children: [
///         GlassListTile(
///           title: const Text('Notifications'),
///           trailing: GlassToggle(value: notify, onChanged: setNotify),
///         ),
///       ],
///     ),
///   ],
/// )
/// ```
///
/// The sections sit [FormMetrics.sectionGap] apart below a
/// [FormMetrics.topInset] top inset, as SwiftUI spaces them; next to a
/// section footer or header the gap tightens to
/// [FormMetrics.captionSectionGap], as the caption takes its place. The form
/// pads itself by the keyboard's height (unless a `Scaffold` above has
/// already made room), so a focused field scrolls into view above it;
/// [keyboardDismissBehavior] chooses whether dragging dismisses it. On
/// the Material path the sections are Material cards on the theme's
/// surface.
class GlassForm extends StatelessWidget {
  /// Creates a form.
  const GlassForm({
    super.key,
    required this.children,
    this.controller,
    this.padding,
    this.backgroundColor,
    this.physics,
    this.primary,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.mode,
  });

  /// The form's sections, usually [GlassListSection]s.
  final List<Widget> children;

  /// The form's scroll controller.
  final ScrollController? controller;

  /// The scroll view's padding in place of SwiftUI's form insets; the
  /// view's safe area and the keyboard are added to it.
  final EdgeInsetsGeometry? padding;

  /// The page colour in place of iOS's systemGroupedBackground (the
  /// Material theme's surface on the Material path).
  final Color? backgroundColor;

  /// The scroll physics.
  final ScrollPhysics? physics;

  /// Whether this is the primary scroll view (see [ScrollView.primary]).
  final bool? primary;

  /// Whether dragging the form dismisses the keyboard.
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// The rendering path; see [GlassRenderMode]. Sections below that set
  /// none take it.
  final GlassRenderMode? mode;

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) {
      final material = effective == EffectiveGlassMode.material;
      final background =
          backgroundColor ??
          (material
              ? Theme.of(context).colorScheme.surface
              : CupertinoDynamicColor.resolve(
                  GlassColors.formBackground,
                  context,
                ));
      final media = MediaQuery.of(context);
      final insets =
          (padding ??
                  EdgeInsets.only(
                    top: material
                        ? FormMetrics.materialTopInset
                        : FormMetrics.topInset,
                    bottom: material
                        ? FormMetrics.materialBottomInset
                        : FormMetrics.bottomInset,
                  ))
              .resolve(Directionality.of(context))
              .add(
                EdgeInsets.only(
                  top: media.padding.top,
                  // The keyboard covers the bottom safe area, so it
                  // replaces it rather than adding to it.
                  bottom: media.viewInsets.bottom > media.padding.bottom
                      ? media.viewInsets.bottom
                      : media.padding.bottom,
                ),
              );
      double gap(Widget above, Widget below) {
        if (material) return FormMetrics.materialSectionGap;
        final captioned =
            (above is GlassListSection && above.footer != null) ||
            (below is GlassListSection && below.header != null);
        return captioned
            ? FormMetrics.captionSectionGap
            : FormMetrics.sectionGap;
      }

      return ColoredBox(
        color: background,
        child: _FormModeScope(
          mode: mode,
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            removeBottom: true,
            child: ListView(
              controller: controller,
              primary: primary,
              physics: physics,
              keyboardDismissBehavior: keyboardDismissBehavior,
              padding: insets,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    SizedBox(height: gap(children[i - 1], children[i])),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Hands the form's [mode] to the sections below that set none.
class _FormModeScope extends StatelessWidget {
  const _FormModeScope({required this.mode, required this.child});

  final GlassRenderMode? mode;
  final Widget child;

  @override
  Widget build(BuildContext context) => mode == null
      ? child
      : ListSectionScope(mode: mode, glass: false, child: child);
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart' show LongPressGestureRecognizer;
import 'package:flutter/material.dart'
    show PopupMenuItem, RelativeRect, showMenu;
import 'package:flutter/physics.dart' show SpringSimulation;
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart' show HapticFeedback;

import '../core/cupertino_l10n.dart';
import '../core/effective_glass_mode.dart';
import '../core/glass_render_mode.dart';
import '../core/liquid_glass_theme.dart';
import '../core/render_mode_resolver.dart';
import '../menu/glass_menu_item.dart';
import '../platform/glass_platform.dart';
import 'context_menu_metrics.dart';
import 'glass_context_menu_route.dart';

/// iOS 26's context menu, like SwiftUI's `.contextMenu`: a long-press
/// lifts [child] over the blurred page and opens the glass menu of
/// [items] by it.
///
/// ```dart
/// GlassContextMenu(
///   items: [
///     GlassMenuItem(label: 'Copy', icon: CupertinoIcons.doc_on_doc,
///         onSelected: copy),
///     GlassMenuItem(label: 'Delete', icon: CupertinoIcons.trash,
///         destructive: true, onSelected: delete),
///   ],
///   child: photo,
/// )
/// ```
///
/// While the finger is down the item eases up under it; the menu opens
/// once the press is held long enough, even if the finger lifts before
/// the menu shows (UIKit's timing, measured).
///
/// A tap outside closes it; choosing an item closes it, then runs the
/// item. Assistive tech gets the items as custom actions. On the Material
/// path the long-press opens a Material popup menu. Laid out as UIKit's
/// UIContextMenuInteraction (measured; see `ContextMenuMetrics`).
class GlassContextMenu extends StatefulWidget {
  /// Creates a context menu for [child].
  const GlassContextMenu({
    super.key,
    required this.items,
    required this.child,
    this.mode,
  });

  /// The menu's rows.
  final List<GlassMenuItem> items;

  /// The item long-pressed.
  final Widget child;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  State<GlassContextMenu> createState() => _GlassContextMenuState();
}

class _GlassContextMenuState extends State<GlassContextMenu>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _scale = ValueNotifier<double>(1);

  /// The finger is down (the item grows) rather than lifted early (it
  /// settles back).
  bool _pressing = false;
  double _releaseFrom = 1, _releaseVelocity = 0;
  double _pressedFor = 0;

  /// Where the press was recognized; the menu opens at
  /// [ContextMenuMetrics.pressLift].
  Offset? _openAt;

  static double _seconds(Duration d) => d.inMicroseconds / 1e6;

  EffectiveGlassMode _effective() => resolveGlassMode(
    requested: widget.mode ?? LiquidGlassTheme.of(context).defaultMode,
    environment: GlassPlatform.instance.environment.value,
    highContrast: MediaQuery.highContrastOf(context),
    supportLiquidGlassOnAndroid: LiquidGlassTheme.of(
      context,
    ).supportLiquidGlassOnAndroid,
  );

  void _tick(Duration elapsed) {
    final t = _seconds(elapsed);
    if (_pressing) {
      _pressedFor = t;
      _scale.value = ContextMenuMetrics.pressed(t);
      final at = _openAt;
      if (at != null && t >= _seconds(ContextMenuMetrics.pressLift)) {
        final pressed = _scale.value;
        _reset();
        _open(at, pressed);
      }
      return;
    }
    final release = SpringSimulation(
      ContextMenuMetrics.pressReleaseSpring,
      _releaseFrom,
      1,
      _releaseVelocity,
    );
    if (release.isDone(t)) return _reset();
    _scale.value = release.x(t);
  }

  void _reset() {
    _ticker.stop();
    _pressing = false;
    _openAt = null;
    _scale.value = 1;
  }

  void _down() {
    if (_effective() == EffectiveGlassMode.material) return;
    _ticker.stop();
    _pressing = true;
    _pressedFor = 0;
    _openAt = null;
    _ticker.start();
  }

  void _cancel() {
    if (!_pressing) return;
    _ticker.stop();
    _pressing = false;
    _releaseFrom = _scale.value;
    _releaseVelocity = ContextMenuMetrics.pressedVelocity(_pressedFor);
    _ticker.start();
  }

  void _start(Offset at) {
    if (_pressing) {
      _openAt = at;
    } else {
      _open(at, 1);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scale.dispose();
    super.dispose();
  }

  Future<void> _open(Offset at, double pressedScale) async {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    final effective = _effective();
    final box = context.findRenderObject()! as RenderBox;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    GlassMenuItem? chosen;
    if (effective == EffectiveGlassMode.material) {
      final screen = MediaQuery.sizeOf(context);
      chosen = await showMenu<GlassMenuItem>(
        context: context,
        position: RelativeRect.fromLTRB(
          at.dx,
          at.dy,
          screen.width - at.dx,
          screen.height - at.dy,
        ),
        items: [
          for (final item in widget.items)
            PopupMenuItem(
              value: item,
              enabled: item.onSelected != null,
              child: Text(item.label),
            ),
        ],
      );
    } else {
      final navigator = Navigator.of(context);
      chosen = await navigator.push(
        GlassContextMenuRoute(
          preview: widget.child,
          previewRect: rect,
          items: widget.items,
          pressedScale: pressedScale,
          mode: widget.mode,
          capturedThemes: InheritedTheme.capture(
            from: context,
            to: navigator.context,
          ),
          barrierLabel: cupertinoL10n(context).modalBarrierDismissLabel,
        ),
      );
    }
    chosen?.onSelected?.call();
  }

  @override
  Widget build(BuildContext context) {
    final material = _effective() == EffectiveGlassMode.material;
    return Semantics(
      customSemanticsActions: {
        for (final item in widget.items)
          if (item.onSelected != null)
            CustomSemanticsAction(label: item.label): item.onSelected!,
      },
      child: RawGestureDetector(
        // The recognizer's duration is fixed when it is made.
        key: ValueKey(material),
        gestures: {
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(
                  duration: material ? null : ContextMenuMetrics.pressRecognize,
                  debugOwner: this,
                ),
                (r) {
                  r
                    ..onLongPressDown = ((_) => _down())
                    ..onLongPressCancel = _cancel
                    ..onLongPressStart = ((d) => _start(d.globalPosition));
                },
              ),
        },
        child: ValueListenableBuilder<double>(
          valueListenable: _scale,
          builder: (context, scale, child) =>
              scale == 1 ? child! : Transform.scale(scale: scale, child: child),
          child: widget.child,
        ),
      ),
    );
  }
}

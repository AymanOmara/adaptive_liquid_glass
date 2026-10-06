import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Registry of content regions that glass may sample.
class GlassBackdropSources {
  GlassBackdropSources._();

  /// Shared instance.
  static final GlassBackdropSources instance = GlassBackdropSources._();

  final List<GlobalKey> _keys = [];
  final ValueNotifier<int> _revision = ValueNotifier(0);

  /// Bumps when sources are added or removed.
  ValueListenable<int> get revision => _revision;

  /// Attached boundaries.
  List<RenderRepaintBoundary> get boundaries => [
    for (final k in _keys)
      if (k.currentContext?.findRenderObject()
          case final RenderRepaintBoundary b when b.attached)
        b,
  ];

  /// Registers the boundary under [k].
  void add(GlobalKey k) {
    if (_keys.contains(k)) return;
    _keys.add(k);
    _revision.value++;
  }

  /// Unregisters the boundary under [k].
  void remove(GlobalKey k) {
    if (!_keys.remove(k)) return;
    _revision.value++;
  }
}

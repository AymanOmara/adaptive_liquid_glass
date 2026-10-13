import 'package:flutter/widgets.dart';

import '../core/glass_colors.dart';
import '../core/glass_render_mode.dart';
import 'control_metrics.dart';
import 'glass_thumb.dart';
import 'slider_geometry.dart';

/// A slider's track, its filled part and its glass thumbs, laid out by
/// [geometry]: shared by `GlassSlider` and `GlassRangeSlider`.
class SliderTrack extends StatelessWidget {
  /// Creates the track.
  const SliderTrack({
    super.key,
    required this.geometry,
    required this.fillFrom,
    required this.fillTo,
    required this.thumbs,
    required this.pressed,
    required this.active,
    required this.inactive,
    this.mode,
    this.thumbBuilder,
  }) : assert(thumbs.length == pressed.length);

  /// The track's layout.
  final SliderGeometry geometry;

  /// Where the fill starts, as a fraction; null fills from the track's
  /// start edge.
  final double? fillFrom;

  /// Where the fill ends, as a fraction (a thumb's centre).
  final double fillTo;

  /// Each thumb's fraction.
  final List<double> thumbs;

  /// Each thumb's press, 0 at rest and 1 held.
  final List<double> pressed;

  /// The fill's colour.
  final Color active;

  /// The rest of the track's colour.
  final Color inactive;

  /// The thumbs' lens rendering path.
  final GlassRenderMode? mode;

  /// Wraps thumb `index` (to give it its own semantics).
  final Widget Function(int index, Widget thumb)? thumbBuilder;

  @override
  Widget build(BuildContext context) {
    final fillStart = fillFrom == null ? 0.0 : geometry.centre(fillFrom!);
    final fillLength = geometry.centre(fillTo) - fillStart;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _place(
          start: 0,
          length: geometry.length,
          cross: ControlMetrics.sliderTrack,
          child: _bar(inactive),
        ),
        _place(
          start: fillStart,
          length: fillLength < 0 ? 0 : fillLength,
          cross: ControlMetrics.sliderTrack,
          child: _bar(active),
        ),
        for (var i = 0; i < thumbs.length; i++)
          _place(
            start:
                geometry.centre(thumbs[i]) -
                ControlMetrics.sliderThumbWidth / 2,
            length: ControlMetrics.sliderThumbWidth,
            cross: ControlMetrics.sliderThumbHeight,
            child: _thumb(i),
          ),
      ],
    );
  }

  Widget _thumb(int i) {
    final thumb = GlassThumb(
      pressed: pressed[i],
      color: GlassColors.thumb,
      mode: mode,
      shadow: true,
      axis: geometry.axis,
    );
    return thumbBuilder?.call(i, thumb) ?? thumb;
  }

  Widget _bar(Color color) => DecoratedBox(
    decoration: ShapeDecoration(shape: const StadiumBorder(), color: color),
  );

  /// Places [child] [start] along the track (from the reading start, or
  /// the bottom), [length] long and [cross] thick, centred across it.
  Widget _place({
    required double start,
    required double length,
    required double cross,
    required Widget child,
  }) {
    final side = (ControlMetrics.sliderHeight - cross) / 2;
    return geometry.axis == Axis.vertical
        ? Positioned(
            bottom: start,
            height: length,
            left: side,
            width: cross,
            child: child,
          )
        : PositionedDirectional(
            start: start,
            width: length,
            top: side,
            height: cross,
            child: child,
          );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../button/glass_button.dart';
import '../button/glass_button_shape.dart';
import '../button/glass_button_style.dart';
import '../button/glass_control_size.dart';
import '../core/glass_render_mode.dart';
import 'glass_photos_picker_filter.dart';
import 'glass_picked_photos.dart';
import 'photos_picker_metrics.dart';
import 'pick_glass_photos.dart';

/// A SwiftUI `PhotosPicker(selection:maxSelectionCount:matching:)`: a glass
/// trigger that opens the system photo picker.
///
/// ```dart
/// GlassPhotosPicker(
///   label: 'Select Photos',
///   maxSelection: 0,
///   onPicked: (photos) => setState(() => _photos = photos),
/// )
/// ```
///
/// Tapping presents the picker (see [pickGlassPhotos]); when it closes
/// with a choice, [onPicked] receives the items as local files, optionally
/// downscaled or converted ([maxWidth], [maxHeight], [imageQuality],
/// [compatibleFormat]). Delete them with [clearGlassPickedPhotos]. Cancelling
/// does not call [onPicked]. A null [onPicked] disables the trigger, and
/// taps are ignored while the picker is open.
///
/// The trigger is [child] in a [GlassButton] when given, like SwiftUI's
/// `PhotosPicker(selection:) { Label(...) }`; otherwise a
/// [GlassButton.icon] with [icon] and [label] beside it (icon-only without
/// [label]). It joins an enclosing `GlassGroup` and is a Material 3 button
/// on the Material path. For a custom trigger, call [pickGlassPhotos].
class GlassPhotosPicker extends StatefulWidget {
  /// Creates a photos picker trigger.
  const GlassPhotosPicker({
    super.key,
    required this.onPicked,
    this.child,
    this.label,
    this.icon = PhotosPickerMetrics.icon,
    this.maxSelection = 1,
    this.filter = GlassPhotosPickerFilter.images,
    this.maxWidth,
    this.maxHeight,
    this.imageQuality,
    this.compatibleFormat = false,
    this.onError,
    this.style = GlassButtonStyle.glass,
    this.size,
    this.shape = GlassButtonShape.automatic,
    this.tint,
    this.mode,
    this.glassId,
    this.semanticLabel,
  }) : assert(maxSelection >= 0, 'maxSelection is 0 (unlimited) or more'),
       assert(maxWidth == null || maxWidth > 0, 'maxWidth is positive'),
       assert(maxHeight == null || maxHeight > 0, 'maxHeight is positive'),
       assert(
         imageQuality == null || (imageQuality >= 0 && imageQuality <= 100),
         'imageQuality is 0 to 100',
       );

  /// Called with the chosen items when the picker closes with a choice;
  /// null disables the trigger.
  final ValueChanged<GlassPickedPhotos>? onPicked;

  /// The trigger's content; replaces [icon] and [label].
  final Widget? child;

  /// Text beside [icon]; null makes the trigger icon-only.
  final String? label;

  /// The glyph when [child] is null. Defaults to
  /// [PhotosPickerMetrics.icon].
  final IconData icon;

  /// The most items the user can choose (SwiftUI's `maxSelectionCount`);
  /// 1 picks a single item, 0 is unlimited.
  final int maxSelection;

  /// What the picker offers (SwiftUI's `matching:`).
  final GlassPhotosPickerFilter filter;

  /// Scales wider photos down to this many pixels; see [pickGlassPhotos].
  final int? maxWidth;

  /// Scales taller photos down to this many pixels; see [pickGlassPhotos].
  final int? maxHeight;

  /// Re-encodes JPEG and HEIC photos at this quality (0-100); see
  /// [pickGlassPhotos].
  final int? imageQuality;

  /// Delivers HEIC photos as JPEG and, on iOS, HEVC videos as H.264; see
  /// [pickGlassPhotos].
  final bool compatibleFormat;

  /// Called when the platform fails to present or load; when null the
  /// error is reported to [FlutterError.reportError].
  final ValueChanged<Object>? onError;

  /// Plain or prominent glass.
  final GlassButtonStyle style;

  /// Defaults to the enclosing `GlassControlSizeScope`, else regular.
  final GlassControlSize? size;

  /// The outline.
  final GlassButtonShape shape;

  /// The prominent fill; defaults to the accent colour.
  final Color? tint;

  /// Rendering mode; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// Morph identity inside a `GlassGroup`.
  final Object? glassId;

  /// What assistive tech reads. Defaults to "Photos" when icon-only.
  final String? semanticLabel;

  @override
  State<GlassPhotosPicker> createState() => _GlassPhotosPickerState();
}

class _GlassPhotosPickerState extends State<GlassPhotosPicker> {
  bool _open = false;

  Future<void> _pick() async {
    if (_open) return;
    _open = true;
    try {
      final photos = await pickGlassPhotos(
        maxSelection: widget.maxSelection,
        filter: widget.filter,
        maxWidth: widget.maxWidth,
        maxHeight: widget.maxHeight,
        imageQuality: widget.imageQuality,
        compatibleFormat: widget.compatibleFormat,
      );
      if (!mounted || photos.isEmpty) return;
      widget.onPicked?.call(photos);
    } on Object catch (e, s) {
      if (e is! PlatformException &&
          e is! MissingPluginException &&
          e is! UnsupportedError) {
        rethrow;
      }
      final onError = widget.onError;
      if (onError != null) {
        onError(e);
      } else {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: e,
            stack: s,
            library: 'adaptive_liquid_glass',
            context: ErrorDescription('while picking photos'),
          ),
        );
      }
    } finally {
      _open = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final onPressed = widget.onPicked == null ? null : _pick;
    final child = widget.child;
    if (child != null) {
      return GlassButton(
        onPressed: onPressed,
        style: widget.style,
        size: widget.size,
        shape: widget.shape,
        tint: widget.tint,
        mode: widget.mode,
        glassId: widget.glassId,
        semanticLabel: widget.semanticLabel,
        child: child,
      );
    }
    final label = widget.label;
    return GlassButton.icon(
      onPressed: onPressed,
      icon: widget.icon,
      label: label == null ? null : Text(label),
      style: widget.style,
      size: widget.size,
      shape: widget.shape,
      tint: widget.tint,
      mode: widget.mode,
      glassId: widget.glassId,
      semanticLabel:
          widget.semanticLabel ??
          (label == null ? PhotosPickerMetrics.semanticLabel : null),
    );
  }
}

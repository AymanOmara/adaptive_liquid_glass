import 'package:flutter/cupertino.dart';

/// Defaults for `GlassPhotosPicker`. The trigger is a glass button, so its
/// geometry comes from `GlassButtonMetrics`; only the glyph lives here.
abstract final class PhotosPickerMetrics {
  /// The default glyph: SF Symbols' `photo.on.rectangle`.
  static const IconData icon = CupertinoIcons.photo_on_rectangle;

  /// What assistive tech reads for an icon-only trigger.
  static const String semanticLabel = 'Photos';
}

import 'package:flutter/foundation.dart';

/// One item chosen in the system photo picker: SwiftUI's `PhotosPickerItem`
/// after it has been loaded with `loadTransferable(type:)` into a file.
///
/// The platform copies each item into the app's temporary (iOS) or cache
/// (Android) directory, so [path] stays readable after the picker closes.
/// The app owns the copy: move it somewhere durable, or delete it when
/// done (`clearGlassPickedPhotos` deletes every copy at once).
@immutable
class GlassPickedPhoto {
  /// Creates a picked item.
  const GlassPickedPhoto({
    required this.path,
    required this.isVideo,
    this.mimeType,
    this.width,
    this.height,
    this.duration,
    this.conversionFailed = false,
    this.index,
  });

  /// Reads the map the platform side sends.
  factory GlassPickedPhoto.fromMap(Map<Object?, Object?> map) =>
      GlassPickedPhoto(
        path: map['path']! as String,
        isVideo: map['isVideo'] as bool? ?? false,
        mimeType: map['mimeType'] as String?,
        width: (map['width'] as num?)?.toInt(),
        height: (map['height'] as num?)?.toInt(),
        duration: switch (map['durationMs']) {
          final num ms => Duration(microseconds: (ms * 1000).round()),
          _ => null,
        },
        conversionFailed: map['conversionFailed'] as bool? ?? false,
        index: (map['index'] as num?)?.toInt(),
      );

  /// The absolute path of the local copy.
  final String path;

  /// Whether the item is a video; otherwise it is an image.
  final bool isVideo;

  /// The MIME type, such as `image/heic` or `video/mp4`, when known.
  final String? mimeType;

  /// The upright pixel width (rotation applied), when the platform could
  /// read it from the image header or the video track; null otherwise.
  final int? width;

  /// The upright pixel height (rotation applied), when the platform could
  /// read it from the image header or the video track; null otherwise.
  final int? height;

  /// How long a video plays, when known; null for images.
  final Duration? duration;

  /// Whether `compatibleFormat` asked for this item to be converted (an
  /// HEVC video to H.264, or HEIC/HEIF photo to JPEG) and the conversion
  /// failed, so the item arrives in its original format.
  ///
  /// False when no compatible-format conversion was needed or it succeeded.
  /// Failed image resizing or quality changes do not set this flag.
  final bool conversionFailed;

  /// Selection order (0-based); null only with an older native plugin.
  final int? index;

  @override
  bool operator ==(Object other) =>
      other is GlassPickedPhoto &&
      other.path == path &&
      other.isVideo == isVideo &&
      other.mimeType == mimeType &&
      other.width == width &&
      other.height == height &&
      other.duration == duration &&
      other.conversionFailed == conversionFailed &&
      other.index == index;

  @override
  int get hashCode => Object.hash(
    path,
    isVideo,
    mimeType,
    width,
    height,
    duration,
    conversionFailed,
    index,
  );

  @override
  String toString() =>
      'GlassPickedPhoto($path, ${isVideo ? 'video' : 'image'}, $mimeType'
      '${width == null ? '' : ', ${width}x$height'}'
      '${duration == null ? '' : ', $duration'}'
      '${conversionFailed ? ', conversion failed' : ''}'
      '${index == null ? '' : ', #$index'})';
}

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

  @override
  bool operator ==(Object other) =>
      other is GlassPickedPhoto &&
      other.path == path &&
      other.isVideo == isVideo &&
      other.mimeType == mimeType &&
      other.width == width &&
      other.height == height &&
      other.duration == duration;

  @override
  int get hashCode =>
      Object.hash(path, isVideo, mimeType, width, height, duration);

  @override
  String toString() =>
      'GlassPickedPhoto($path, ${isVideo ? 'video' : 'image'}, $mimeType'
      '${width == null ? '' : ', ${width}x$height'}'
      '${duration == null ? '' : ', $duration'})';
}

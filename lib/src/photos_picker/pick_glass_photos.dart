import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'glass_photos_picker_filter.dart';
import 'glass_picked_photo.dart';

const MethodChannel _channel = MethodChannel('adaptive_liquid_glass');

/// Presents the system photo picker and returns what was chosen: the
/// function behind `GlassPhotosPicker`, SwiftUI's `PhotosPicker` with a
/// custom trigger.
///
/// ```dart
/// final photos = await pickGlassPhotos(maxSelection: 0);
/// for (final p in photos) print(p.path);
/// ```
///
/// [maxSelection] caps the choice (SwiftUI's `maxSelectionCount`); 1 picks
/// a single item and 0 is unlimited. [filter] is SwiftUI's `matching:`.
/// Cancelling returns an empty list.
///
/// Items arrive as the library holds them unless asked otherwise:
/// - [maxWidth] and [maxHeight] (pixels) scale a larger photo down to fit,
///   keeping its aspect ratio; smaller photos are not enlarged.
/// - [imageQuality] (0-100) re-encodes JPEG and HEIC photos at that
///   quality.
/// - [compatibleFormat] turns HEIC/HEIF photos into JPEG and, on iOS, HEVC
///   videos into H.264 (`.mp4`).
///
/// A re-encoded photo keeps its format where the platform can write it
/// (iOS: HEIC, JPEG, PNG; Android: JPEG, PNG), else becomes JPEG. GIFs are
/// left as they are, and Android does not transcode videos.
///
/// iOS presents `PHPickerViewController`, which needs no photo library
/// permission. Android presents the system Photo Picker
/// (`MediaStore.ACTION_PICK_IMAGES`) where available and the document
/// picker otherwise; neither needs a storage permission. Each item is
/// copied to a local file; see [GlassPickedPhoto] and
/// [clearGlassPickedPhotos]. Throws an [UnsupportedError] on other
/// platforms and a [PlatformException] when the platform fails (another
/// picker already open, no window to present from).
Future<List<GlassPickedPhoto>> pickGlassPhotos({
  int maxSelection = 1,
  GlassPhotosPickerFilter filter = GlassPhotosPickerFilter.images,
  int? maxWidth,
  int? maxHeight,
  int? imageQuality,
  bool compatibleFormat = false,
}) async {
  assert(maxSelection >= 0, 'maxSelection is 0 (unlimited) or more');
  assert(maxWidth == null || maxWidth > 0, 'maxWidth is positive');
  assert(maxHeight == null || maxHeight > 0, 'maxHeight is positive');
  assert(
    imageQuality == null || (imageQuality >= 0 && imageQuality <= 100),
    'imageQuality is 0 to 100',
  );
  if (!_supported) {
    throw UnsupportedError('pickGlassPhotos supports iOS and Android only');
  }
  final items = await _channel.invokeListMethod<Object?>('pickPhotos', {
    'maxSelection': maxSelection,
    'filter': filter.name,
    'maxWidth': ?maxWidth,
    'maxHeight': ?maxHeight,
    'imageQuality': ?imageQuality,
    if (compatibleFormat) 'compatibleFormat': true,
  });
  return [
    for (final item in items ?? const <Object?>[])
      GlassPickedPhoto.fromMap(item! as Map<Object?, Object?>),
  ];
}

/// Deletes every copy [pickGlassPhotos] has made: the
/// `adaptive_liquid_glass_picker` folder in the app's temporary directory
/// (iOS, `NSTemporaryDirectory()`) or cache directory (Android,
/// `cacheDir`).
///
/// Paths from earlier picks stop working, so move anything to keep out of
/// that folder first. Call it once the files are no longer needed, for
/// example after uploading them or on the next launch. Does nothing on
/// other platforms.
Future<void> clearGlassPickedPhotos() async {
  if (!_supported) return;
  await _channel.invokeMethod<void>('clearPickedPhotos');
}

bool get _supported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

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
/// iOS presents `PHPickerViewController`, which needs no photo library
/// permission. Android presents the system Photo Picker
/// (`MediaStore.ACTION_PICK_IMAGES`) where available and the document
/// picker otherwise; neither needs a storage permission. Each item is
/// copied to a local file; see [GlassPickedPhoto]. Throws an
/// [UnsupportedError] on other platforms and a [PlatformException] when
/// the platform fails (another picker already open, no window to present
/// from).
Future<List<GlassPickedPhoto>> pickGlassPhotos({
  int maxSelection = 1,
  GlassPhotosPickerFilter filter = GlassPhotosPickerFilter.images,
}) async {
  assert(maxSelection >= 0, 'maxSelection is 0 (unlimited) or more');
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.iOS &&
          defaultTargetPlatform != TargetPlatform.android)) {
    throw UnsupportedError('pickGlassPhotos supports iOS and Android only');
  }
  final items = await _channel.invokeListMethod<Object?>('pickPhotos', {
    'maxSelection': maxSelection,
    'filter': filter.name,
  });
  return [
    for (final item in items ?? const <Object?>[])
      GlassPickedPhoto.fromMap(item! as Map<Object?, Object?>),
  ];
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'glass_photo_import_controller.dart';
import 'glass_photo_import_progress.dart';
import 'glass_photos_picker_filter.dart';
import 'glass_picked_photo.dart';
import 'glass_picked_photos.dart';
import 'photo_import_tracker.dart';

const MethodChannel _channel = MethodChannel('adaptive_liquid_glass');
int _nextImport = 0;

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
/// a single item and 0 removes the app's cap. Android's system Photo Picker
/// still applies its platform selection maximum. [filter] is SwiftUI's `matching:`.
/// Cancelling returns an empty list.
///
/// Items arrive as the library holds them unless asked otherwise:
/// - [maxWidth] and [maxHeight] (pixels) scale a larger photo down to fit,
///   keeping its aspect ratio; smaller photos are not enlarged.
/// - [imageQuality] (0-100) re-encodes JPEG and HEIC photos at that
///   quality.
/// - [compatibleFormat] turns HEIC/HEIF photos into JPEG and HEVC videos
///   into H.264 (`.mp4`). An item that fails to convert arrives as it is,
///   with [GlassPickedPhoto.conversionFailed] set.
///
/// A re-encoded photo keeps its format where the platform can write it
/// (iOS: HEIC, JPEG, PNG; Android: JPEG, PNG), else becomes JPEG. GIFs are
/// left as they are.
///
/// The result is a [GlassPickedPhotos], a list that also reports
/// [GlassPickedPhotos.droppedCount]: items chosen beyond [maxSelection]
/// in the Android document-picker fallback, which cannot enforce it.
///
/// iOS presents `PHPickerViewController`, which needs no photo library
/// permission. Android presents the system Photo Picker
/// (`MediaStore.ACTION_PICK_IMAGES`) where available and the document
/// picker otherwise; neither needs a storage permission. Each item is
/// copied to a local file; see [GlassPickedPhoto] and
/// [clearGlassPickedPhotos]. Throws an [UnsupportedError] on other
/// platforms and a [PlatformException] when the platform fails (another
/// picker already open, no window to present from).
///
/// [onItemReady] optionally receives each local file as soon as that item has
/// finished copying and conversion, before later items finish. The final result
/// still contains the full selection. Already delivered files remain valid if
/// a later item fails; this future may still throw. Callback errors are reported
/// through [FlutterError.reportError] without interrupting the import. With an
/// older native plugin, callbacks are delivered with the final result instead.
/// On iOS, [onItemReady] order may differ from selection order; use
/// [GlassPickedPhoto.index] to place an item.
///
/// [onProgress] receives throttled [GlassPhotoImportProgress] snapshots;
/// use its `fraction` to drive one progress bar.
///
/// [controller] watches the import and can stop it: call
/// [GlassPhotoImportController.cancel] and the future completes with the
/// items already finished and [GlassPickedPhotos.cancelled] true. Cancel is
/// not an error. One controller drives one import at a time.
Future<GlassPickedPhotos> pickGlassPhotos({
  int maxSelection = 1,
  GlassPhotosPickerFilter filter = GlassPhotosPickerFilter.images,
  int? maxWidth,
  int? maxHeight,
  int? imageQuality,
  bool compatibleFormat = false,
  ValueChanged<GlassPickedPhoto>? onItemReady,
  ValueChanged<GlassPhotoImportProgress>? onProgress,
  GlassPhotoImportController? controller,
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
  final delivered = <String>{};
  void deliver(GlassPickedPhoto photo) {
    if (onItemReady == null || !delivered.add(photo.path)) return;
    try {
      onItemReady(photo);
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'adaptive_liquid_glass',
          context: ErrorDescription('while notifying an imported photo'),
        ),
      );
    }
  }

  final tracker = PhotoImportTracker();
  var cancelled = false;
  late final GlassPhotoImportBinding? binding;
  void report(GlassPhotoImportProgress p) {
    binding?.update(p);
    if (onProgress == null) return;
    try {
      onProgress(p);
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'adaptive_liquid_glass',
          context: ErrorDescription('while reporting photo import progress'),
        ),
      );
    }
  }

  final imports =
      onItemReady == null && onProgress == null && controller == null
      ? null
      : MethodChannel(
          'adaptive_liquid_glass/photo_import/${DateTime.now().microsecondsSinceEpoch}_${_nextImport++}',
        );
  binding = controller == null
      ? null
      : attachImport(controller, () {
          cancelled = true;
          _channel
              .invokeMethod<void>('cancelPhotoImport', {
                'importChannel': imports!.name,
              })
              .catchError((Object _) {}); // older plugin or stale name: no-op
        });
  imports?.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'itemReady':
        deliver(
          GlassPickedPhoto.fromMap(call.arguments as Map<Object?, Object?>),
        );
      case 'progress':
        report(tracker.onEvent(call.arguments as Map<Object?, Object?>));
    }
  });
  try {
    // A list of items, or {items, dropped, cancelled}.
    final Object? reply;
    try {
      reply = await _channel.invokeMethod<Object?>('pickPhotos', {
        'maxSelection': maxSelection,
        'filter': filter.name,
        'maxWidth': ?maxWidth,
        'maxHeight': ?maxHeight,
        'imageQuality': ?imageQuality,
        if (compatibleFormat) 'compatibleFormat': true,
        if (imports != null) 'importChannel': imports.name,
      });
    } on PlatformException {
      // Cancel is not an error: keep what was delivered.
      if (!cancelled) rethrow;
      return GlassPickedPhotos(const [], cancelled: true);
    }
    final (items, dropped, nativeCancelled) = switch (reply) {
      final Map<Object?, Object?> map => (
        map['items'] as List<Object?>?,
        (map['dropped'] as num?)?.toInt() ?? 0,
        map['cancelled'] == true,
      ),
      final List<Object?> list => (list, 0, false),
      _ => (null, 0, false),
    };
    final photos = GlassPickedPhotos(
      [
        for (final item in items ?? const <Object?>[])
          GlassPickedPhoto.fromMap(item! as Map<Object?, Object?>),
      ],
      droppedCount: dropped,
      cancelled: nativeCancelled || (cancelled && reply == null),
    );
    // Reconcile events with the final result. This also supports older plugins
    // and prevents a late final event from losing or duplicating a callback.
    for (final photo in photos) {
      deliver(photo);
    }
    report(tracker.done());
    return photos;
  } finally {
    imports?.setMethodCallHandler(null);
    binding?.detach();
  }
}

/// Deletes every copy [pickGlassPhotos] has made: the
/// `adaptive_liquid_glass_picker` folder in the app's temporary directory
/// (iOS, `NSTemporaryDirectory()`) or cache directory (Android,
/// `cacheDir`).
///
/// Paths from earlier picks stop working, so move anything to keep out of
/// that folder first. Call it once the files are no longer needed, for
/// example after uploading them or on the next launch. Does nothing on
/// other platforms. Throws a [PlatformException] with code `already_active`
/// while a picker or import is active, so cleanup cannot delete incoming files.
/// A filesystem deletion failure throws `cleanup_failed`; already missing
/// copies count as successfully cleared. Cleanup can be retried after failure.
Future<void> clearGlassPickedPhotos() async {
  if (!_supported) return;
  await _channel.invokeMethod<void>('clearPickedPhotos');
}

bool get _supported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

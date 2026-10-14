import 'dart:collection';

import 'glass_picked_photo.dart';

/// What `pickGlassPhotos` returns: the picked items as an ordinary
/// (growable) list, plus [droppedCount].
///
/// It is a `List<GlassPickedPhoto>`, so code written against the plain
/// list keeps working.
class GlassPickedPhotos extends ListBase<GlassPickedPhoto> {
  /// Wraps [items]; [droppedCount] chosen items were not returned.
  GlassPickedPhotos(Iterable<GlassPickedPhoto> items, {this.droppedCount = 0})
    : _items = List.of(items);

  final List<GlassPickedPhoto> _items;

  /// How many chosen items were left out because they went over
  /// `maxSelection`.
  ///
  /// Only the Android document picker (the fallback before Android 11, or
  /// on Android 11-12 without SDK extension 2) lets the user choose more
  /// than `maxSelection`; the extra items are dropped from the end and
  /// counted here. Always 0 on iOS and with the Android Photo Picker,
  /// which enforce the limit in their UI.
  final int droppedCount;

  @override
  int get length => _items.length;

  @override
  set length(int value) => _items.length = value;

  @override
  GlassPickedPhoto operator [](int index) => _items[index];

  @override
  void operator []=(int index, GlassPickedPhoto value) => _items[index] = value;

  @override
  void add(GlassPickedPhoto element) => _items.add(element);

  @override
  void addAll(Iterable<GlassPickedPhoto> iterable) => _items.addAll(iterable);
}

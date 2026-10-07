import 'dart:ui' show Color;

final RegExp _hex = RegExp(r'^[0-9a-fA-F]+$');

/// Parses `#RRGGBB` or `#AARRGGBB` (the `#` optional, any case) into a
/// colour; null when the text is not one.
Color? parseHexColor(String text) {
  var digits = text.trim();
  if (digits.startsWith('#')) digits = digits.substring(1);
  if (!_hex.hasMatch(digits)) return null;
  final value = int.parse(digits, radix: 16);
  if (digits.length == 6) return Color(0xFF000000 | value);
  if (digits.length == 8) return Color(value);
  return null;
}

/// Formats a colour as `#RRGGBB`, or `#AARRGGBB` when [withAlpha] and the
/// colour is not opaque.
String formatHexColor(Color color, {bool withAlpha = true}) {
  final argb = color.toARGB32();
  final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  if (!withAlpha || argb >> 24 == 0xFF) return '#${rgb.toUpperCase()}';
  final a = (argb >> 24).toRadixString(16).padLeft(2, '0');
  return '#${(a + rgb).toUpperCase()}';
}

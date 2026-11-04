/// The progress a loading ring shows for [value]: null for null, NaN or
/// infinity (an indeterminate spinner), else [value] clamped to 0-1.
double? loadingRingValue(double? value) {
  if (value == null || !value.isFinite) return null;
  return value.clamp(0.0, 1.0);
}

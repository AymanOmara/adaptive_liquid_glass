part of 'glass_disclosure_group.dart';

/// The parent's value clamped to 0..1, so no spring overshoot could
/// reach SizeTransition or FadeTransition.
class _ClampedAnimation extends ProxyAnimation {
  _ClampedAnimation(super.parent);

  @override
  double get value => super.value.clamp(0.0, 1.0);
}

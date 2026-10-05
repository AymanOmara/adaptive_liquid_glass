/// iOS 26 Liquid Glass for Flutter with Material 3 counterparts on Android.
///
/// ```dart
/// import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
///
/// const Text('Hello').glassEffect(padding: const EdgeInsets.all(12));
/// ```
///
/// Start with [LiquidGlass] (or the [GlassEffect.glassEffect] shorthand),
/// group neighbours with [GlassGroup], and pick the material with [Glass]
/// and the outline with [GlassShape]. [GlassTabBar] is iOS 26's floating
/// tab bar, built from them.
library;

export 'src/button/glass_button.dart' hide GlassButtonMetricsScope;
export 'src/core/glass.dart' show Glass, GlassVariant;
export 'src/core/glass_render_mode.dart' show GlassRenderMode;
export 'src/core/glass_shape.dart' hide concentricRadius;
export 'src/core/theme.dart';
export 'src/foreground/glass_backdrop_source.dart' show GlassBackdropSource;
export 'src/foreground/glass_foreground.dart';
export 'src/glass_effect.dart';
export 'src/group/glass_group.dart' show GlassGroup;
export 'src/liquid_glass.dart' show LiquidGlass;
export 'src/navigation/glass_back_button.dart' show GlassBackButton;
export 'src/tab_bar/glass_tab_bar.dart';

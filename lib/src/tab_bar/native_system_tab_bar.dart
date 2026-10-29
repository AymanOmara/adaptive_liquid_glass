import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'glass_tab_bar_item.dart';
import 'native_tab_icon.dart';

/// Older Flutter engines can leave UIKit tab gestures in a stale state.
/// Probe the public getter dynamically so the package still compiles against
/// its minimum Flutter SDK; those versions retain the Flutter tab renderer.
final bool supportsNativeTabGestures = _supportsNativeTabGestures();

bool _supportsNativeTabGestures() {
  try {
    final dynamic view = const UiKitView(viewType: '');
    return view.gestureBlockingPolicy != null;
  } on NoSuchMethodError {
    return false;
  }
}

/// System tab metadata, with stable glyph identity across selection updates.
@immutable
class NativeTabItem {
  /// Creates a native symbol or a bundled Flutter icon template.
  const NativeTabItem({
    required this.label,
    this.symbol,
    this.activeSymbol,
    this.icon,
    this.activeIcon,
    this.badge,
  });

  /// The system label.
  final String label;

  /// The unselected SF Symbol, when provided.
  final String? symbol;

  /// The selected SF Symbol, when provided.
  final String? activeSymbol;

  /// The bundled Flutter glyph to rasterize once.
  final IconData? icon;

  /// The selected bundled Flutter glyph.
  final IconData? activeIcon;

  /// The optional system badge text.
  final String? badge;
  @override
  bool operator ==(Object other) =>
      other is NativeTabItem &&
      label == other.label &&
      symbol == other.symbol &&
      activeSymbol == other.activeSymbol &&
      icon == other.icon &&
      activeIcon == other.activeIcon &&
      badge == other.badge;
  @override
  int get hashCode =>
      Object.hash(label, symbol, activeSymbol, icon, activeIcon, badge);
}

/// Returns null for custom widgets or icons that need Flutter rendering.
List<NativeTabItem>? nativeTabItems(List<GlassTabBarItem> items) {
  final result = <NativeTabItem>[];
  for (final item in items) {
    final name = item.symbolName;
    final active = item.activeSymbolName;
    if (item.isSpacer ||
        (name == null &&
            (item.icon == null ||
                !canRasterizeNativeTabIcon(item.icon!) ||
                (item.activeIcon != null &&
                    !canRasterizeNativeTabIcon(item.activeIcon!))))) {
      return null;
    }
    result.add(
      NativeTabItem(
        label: item.label,
        symbol: name,
        activeSymbol: active,
        icon: item.icon,
        activeIcon: item.activeIcon,
        badge: item.badge,
      ),
    );
  }
  return result;
}

/// Native control for stock symbols and bundled icons; custom bars retain Flutter's
/// layout. iOS owns the material, vibrant labels and press/drag lens together.
class NativeSystemTabBar extends StatefulWidget {
  /// Creates the native control and its Flutter fallback.
  const NativeSystemTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.tint,
    required this.dark,
    required this.width,
    required this.height,
    required this.fallback,
  });

  /// The native tab labels, symbols and badges.
  final List<NativeTabItem> items;

  /// The index selected by the app.
  final int selectedIndex;

  /// Called when the system control picks a tab.
  final ValueChanged<int> onSelected;

  /// The selected tab tint; null keeps UIKit's own dynamic system tint.
  final Color? tint;

  /// The app appearance supplied to UIKit.
  final bool dark;

  /// The visible glass width, excluding overhang.
  final double width;

  /// The visible glass height, excluding overhang.
  final double height;

  /// The existing Flutter bar for unsupported native content.
  final Widget fallback;
  @override
  State<NativeSystemTabBar> createState() => _NativeSystemTabBarState();
}

class _NativeSystemTabBarState extends State<NativeSystemTabBar> {
  static const _overhang = 24.0;
  MethodChannel? _channel;
  bool _unsupported = false;
  int _revision = 0;
  int _imageGeneration = 0;
  Set<IconData> _requestedIcons = {};
  Map<IconData, Uint8List> _images = {};
  double? _imageRatio;
  TextDirection? _imageDirection;
  bool _imageFailed = false;

  bool get _imagesReady =>
      !_imageFailed && _requestedIcons.every(_images.containsKey);

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_fontsChanged);
  }

  void _fontsChanged() {
    if (_requestedIcons.isEmpty) return;
    // Cached PNGs do not relayout like Flutter's Icon when a font loads.
    // Invalidate in-flight work too, so an older glyph cannot win the race.
    _imageRatio = null;
    setState(() {
      _prepareImages();
    });
  }

  Future<void> _prepareImages() async {
    final icons = {
      for (final item in widget.items) ...[
        if (item.icon != null) item.icon!,
        if (item.activeIcon != null) item.activeIcon!,
      ],
    };
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final direction = Directionality.of(context);
    if (setEquals(icons, _requestedIcons) &&
        ratio == _imageRatio &&
        direction == _imageDirection) {
      _update();
      return;
    }
    final generation = ++_imageGeneration;
    _requestedIcons = icons;
    _imageRatio = ratio;
    _imageDirection = direction;
    _imageFailed = false;
    _images = {};
    if (icons.isEmpty) {
      _update();
      return;
    }
    _revision++;
    _channel?.setMethodCallHandler(null);
    _channel = null;
    try {
      final entries = await Future.wait(
        icons.map(
          (icon) async => MapEntry(
            icon,
            await rasterizeNativeTabIcon(
              icon,
              pixelRatio: ratio,
              textDirection: direction,
            ),
          ),
        ),
      );
      if (!mounted || generation != _imageGeneration) return;
      setState(() => _images = Map.fromEntries(entries));
    } on Object {
      if (mounted && generation == _imageGeneration) {
        setState(() => _imageFailed = true);
      }
    }
  }

  Map<String, Object?> get _payload => {
    'items': [
      for (final item in widget.items)
        {
          'label': item.label,
          'symbol': item.symbol,
          'activeSymbol': item.activeSymbol,
          'badge': item.badge,
          'image': _images[item.icon],
          'activeImage': _images[item.activeIcon],
        },
    ],
    'selectedIndex': widget.selectedIndex,
    'dark': widget.dark,
    'tint': widget.tint?.toARGB32(),
    'rtl': Directionality.of(context) == TextDirection.rtl,
    'overhang': _overhang,
    'imageScale': _imageRatio,
  };

  void _useFallback() {
    _revision++;
    _channel?.setMethodCallHandler(null);
    _channel = null;
    setState(() => _unsupported = true);
  }

  Future<void> _update() async {
    final channel = _channel;
    if (channel == null || !_imagesReady) return;
    final revision = ++_revision;
    try {
      final supported = await channel.invokeMethod<bool>('update', _payload);
      if (!mounted || revision != _revision) return;
      if (supported != true) _useFallback();
    } on PlatformException {
      if (mounted && revision == _revision) _useFallback();
    } on MissingPluginException {
      if (mounted && revision == _revision) _useFallback();
    }
  }

  @override
  void didUpdateWidget(NativeSystemTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_unsupported && !listEquals(widget.items, oldWidget.items)) {
      _unsupported = false;
      _channel?.setMethodCallHandler(null);
      _channel = null;
    }
    _prepareImages();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepareImages();
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_fontsChanged);
    _imageGeneration++;
    _revision++;
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_unsupported || !supportsNativeTabGestures || !_imagesReady) {
      return widget.fallback;
    }
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -_overhang,
            top: -_overhang,
            width: widget.width + 2 * _overhang,
            height: widget.height + 2 * _overhang,
            child: UiKitView(
              viewType: 'adaptive_liquid_glass/native_tabs',
              layoutDirection: Directionality.of(context),
              creationParams: _payload,
              creationParamsCodec: const StandardMessageCodec(),
              gestureRecognizers: {
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
              onPlatformViewCreated: (id) {
                final channel = MethodChannel(
                  'adaptive_liquid_glass/native_tabs_$id',
                );
                _channel = channel;
                channel.setMethodCallHandler((call) async {
                  if (call.method == 'unsupported') {
                    if (mounted && identical(_channel, channel)) _useFallback();
                    return null;
                  }
                  if (call.method != 'selected' ||
                      call.arguments is! int ||
                      !mounted ||
                      _unsupported ||
                      !identical(_channel, channel)) {
                    return null;
                  }
                  final index = call.arguments as int;
                  if (index < 0 || index >= widget.items.length) {
                    return widget.selectedIndex;
                  }
                  if (index != widget.selectedIndex) {
                    widget.onSelected(index);
                  }
                  // Preserve the controlled selection contract when the parent
                  // declines a pick, or changes it to a different tab.
                  await SchedulerBinding.instance.endOfFrame;
                  return mounted ? widget.selectedIndex : null;
                });
                _update();
              },
            ),
          ),
        ],
      ),
    );
  }
}

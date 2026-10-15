import 'dart:io';

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart' show CupertinoColors, CupertinoIcons;
import 'package:flutter/material.dart';

import 'android_glass_toggle.dart';

/// `flutter run -t lib/components_demo.dart`: every component on one
/// `GlassScaffold`, over a photo. Add `--dart-define=MODE=shader` (or
/// `native`, `material`) to force a rendering path, or
/// `--dart-define=ANDROID_GLASS=true` for the iOS look on Android.
Future<void> main() async {
  // Preloads the shaders on any platform, as MODE may force them.
  await AdaptiveLiquidGlass.initialize(mode: GlassRenderMode.shader);
  const mode = String.fromEnvironment('MODE');
  runApp(
    AndroidGlassTheme(
      data: LiquidGlassThemeData(
        defaultMode: switch (mode) {
          'shader' => GlassRenderMode.shader,
          'native' => GlassRenderMode.native,
          'material' => GlassRenderMode.material,
          _ => GlassRenderMode.auto,
        },
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        darkTheme: ThemeData(brightness: Brightness.dark),
        home: const ComponentsDemo(),
      ),
    ),
  );
}

enum _Period { day, week, month }

const _periods = [
  GlassPickerItem(value: _Period.day, label: 'Day'),
  GlassPickerItem(value: _Period.week, label: 'Week'),
  GlassPickerItem(value: _Period.month, label: 'Month'),
];

/// The components showcase.
class ComponentsDemo extends StatefulWidget {
  /// Creates the showcase.
  const ComponentsDemo({super.key});

  @override
  State<ComponentsDemo> createState() => _ComponentsDemoState();
}

class _ComponentsDemoState extends State<ComponentsDemo> {
  int _tab = 0;
  _Period _period = _Period.week;
  bool _wifi = true;
  double _volume = 0.6;
  RangeValues _hours = const RangeValues(9, 17);
  double _brightness = 0.4;
  bool _toolbar = false;
  bool _advanced = false;
  double _count = 3;
  DateTime _date = DateTime(2026, 10, 6);
  Color _accent = const Color(0xFF007AFF);
  String? _emailError;
  final _rows = ['Copied Image', 'Meeting notes', 'Shopping list'];
  int _page = 0;
  final _tags = {'Travel': true, 'Food': false, 'Music': false};
  List<GlassPickedPhoto> _photos = const [];

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => GlassScaffold(
    navigationBar: GlassNavigationBar(
      title: const Text('Components'),
      actions: [
        GlassMenuButton(
          icon: CupertinoIcons.ellipsis,
          semanticLabel: 'More',
          items: [
            GlassMenuItem(
              label: 'Copy',
              icon: CupertinoIcons.doc_on_doc,
              onSelected: () => _snack('Copy'),
            ),
            GlassMenuItem(
              label: 'Share',
              icon: CupertinoIcons.share,
              onSelected: () => _snack('Share'),
            ),
            GlassMenuItem(
              label: 'Delete',
              icon: CupertinoIcons.trash,
              destructive: true,
              onSelected: () => _snack('Delete'),
            ),
          ],
        ),
      ],
    ),
    tabBar: _toolbar
        ? null
        : GlassTabBar(
            items: const [
              GlassTabBarItem(icon: CupertinoIcons.house_fill, label: 'Home'),
              GlassTabBarItem(icon: CupertinoIcons.music_note, label: 'Music'),
              GlassTabBarItem(
                icon: CupertinoIcons.gear_solid,
                label: 'Settings',
              ),
            ],
            selectedIndex: _tab,
            onSelected: (i) => setState(() => _tab = i),
            onSearch: () => _snack('Search'),
          ),
    toolbar: _toolbar
        ? GlassToolbar(
            children: [
              GlassButton.icon(
                onPressed: () => _snack('Reply'),
                icon: CupertinoIcons.reply,
                semanticLabel: 'Reply',
              ),
              GlassButton.icon(
                onPressed: () => _snack('Flag'),
                icon: CupertinoIcons.flag,
                semanticLabel: 'Flag',
              ),
              const GlassToolbarSpacer(),
              GlassButton.icon(
                onPressed: () => _snack('Compose'),
                icon: CupertinoIcons.square_pencil,
                semanticLabel: 'Compose',
              ),
            ],
          )
        : null,
    bottomAccessory: GlassBottomAccessory(
      onPressed: () => _snack('Now Playing'),
      child: const Row(
        children: [
          Icon(CupertinoIcons.music_note_2, size: 20),
          SizedBox(width: 10),
          Expanded(child: Text('Liquid Glass — Now Playing')),
          Icon(CupertinoIcons.play_fill, size: 20),
        ],
      ),
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        if (const bool.fromEnvironment('BLACK_BACKGROUND'))
          const ColoredBox(color: Colors.black)
        else if (const bool.fromEnvironment('PLAIN_BACKGROUND'))
          ColoredBox(color: Theme.of(context).scaffoldBackgroundColor)
        else
          Image.asset('assets/backgrounds/photo.png', fit: BoxFit.cover),
        // The scaffold pads the body's MediaQuery by the bars; read it
        // below the scaffold, not with this State's context.
        GlassSearchable(
          placement: GlassSearchablePlacement.navigationBar,
          scopes: const ['All', 'Recent'],
          suggestionsBuilder: (context, search) => search.text.isEmpty
              ? const []
              : [
                  GlassSearchSuggestion(
                    title: Text('${search.text} in Components'),
                    leading: const Icon(CupertinoIcons.search),
                  ),
                ],
          child: Builder(
            builder: (context) => GlassRefresh(
              onRefresh: () => Future<void>.delayed(const Duration(seconds: 2)),
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  20,
                  16,
                  20,
                  24,
                ).add(MediaQuery.paddingOf(context)),
                children: [
                  GlassSegmentedControl<_Period>(
                    segments: const [
                      GlassSegment(value: _Period.day, label: Text('Day')),
                      GlassSegment(value: _Period.week, label: Text('Week')),
                      GlassSegment(value: _Period.month, label: Text('Month')),
                    ],
                    selected: _period,
                    onChanged: (p) => setState(() => _period = p),
                  ),
                  const SizedBox(height: 24),
                  LiquidGlass(
                    shape: const GlassShape.rect(26),
                    padding: const EdgeInsetsDirectional.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(child: Text('Wi-Fi')),
                            GlassToggle(
                              value: _wifi,
                              onChanged: (v) => setState(() => _wifi = v),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(CupertinoIcons.speaker_fill, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GlassSlider(
                                value: _volume,
                                onChanged: (v) => setState(() => _volume = v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(CupertinoIcons.speaker_3_fill, size: 18),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Open ${_hours.start.round()}:00 – '
                          '${_hours.end.round()}:00',
                        ),
                        GlassRangeSlider(
                          values: _hours,
                          min: 0,
                          max: 24,
                          divisions: 24,
                          semanticFormatter: (v) => '${v.round()}:00',
                          onChanged: (v) => setState(() => _hours = v),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 160,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GlassSlider(
                                axis: Axis.vertical,
                                value: _brightness,
                                onChanged: (v) =>
                                    setState(() => _brightness = v),
                              ),
                              const SizedBox(width: 24),
                              GlassRangeSlider(
                                axis: Axis.vertical,
                                values: _hours,
                                min: 0,
                                max: 24,
                                divisions: 24,
                                onChanged: (v) => setState(() => _hours = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Expanded(
                              child: Text('Toolbar instead of tabs'),
                            ),
                            GlassToggle(
                              value: _toolbar,
                              onChanged: (v) => setState(() => _toolbar = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // SwiftUI's button styles without glass.
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      GlassButton(
                        onPressed: () => _snack('Bordered'),
                        style: GlassButtonStyle.bordered,
                        child: const Text('Bordered'),
                      ),
                      GlassButton(
                        onPressed: () => _snack('Prominent'),
                        style: GlassButtonStyle.borderedProminent,
                        child: const Text('Prominent'),
                      ),
                      GlassButton.icon(
                        onPressed: () => _snack('Delete'),
                        style: GlassButtonStyle.bordered,
                        role: GlassButtonRole.destructive,
                        icon: CupertinoIcons.trash,
                        label: const Text('Delete'),
                      ),
                      GlassButton(
                        onPressed: () => _snack('Borderless'),
                        style: GlassButtonStyle.borderless,
                        child: const Text('Borderless'),
                      ),
                      GlassButton(
                        onPressed: () => _snack('Plain'),
                        style: GlassButtonStyle.plain,
                        child: const Text('Plain'),
                      ),
                      const GlassButton(
                        onPressed: null,
                        style: GlassButtonStyle.bordered,
                        child: Text('Disabled'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      GlassButton(
                        onPressed: () => showGlassSheet<void>(
                          context: context,
                          detents: const [
                            GlassSheetDetent.medium,
                            GlassSheetDetent.large,
                          ],
                          builder: (context) => const Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                              24,
                              16,
                              24,
                              32,
                            ),
                            child: Text(
                              'Drag up for the large sheet, down to close.',
                            ),
                          ),
                        ),
                        child: const Text('Sheet'),
                      ),
                      GlassButton(
                        onPressed: () => showGlassAlert(
                          context: context,
                          title: 'Delete photo?',
                          message:
                              'This photo will be deleted from all your '
                              'devices.',
                          actions: const [
                            GlassDialogAction(
                              label: 'Cancel',
                              role: GlassButtonRole.cancel,
                            ),
                            GlassDialogAction(
                              label: 'Delete',
                              role: GlassButtonRole.destructive,
                            ),
                          ],
                        ),
                        child: const Text('Alert'),
                      ),
                      GlassButton(
                        onPressed: () => showGlassConfirmationDialog(
                          context: context,
                          title: 'Photo',
                          actions: const [
                            GlassDialogAction(label: 'Share'),
                            GlassDialogAction(
                              label: 'Delete',
                              role: GlassButtonRole.destructive,
                            ),
                            GlassDialogAction(
                              label: 'Cancel',
                              role: GlassButtonRole.cancel,
                            ),
                          ],
                        ),
                        child: const Text('Dialog'),
                      ),
                      GlassButton(
                        onPressed: () => showGlassToast(
                          context,
                          message: 'Photo saved',
                          icon: CupertinoIcons.checkmark_circle_fill,
                          action: GlassToastAction(
                            label: 'Undo',
                            onPressed: () => _snack('Undone'),
                          ),
                        ),
                        child: const Text('Toast'),
                      ),
                      GlassButton(
                        onPressed: () => showGlassActionSheet(
                          context: context,
                          title: 'Photo',
                          actions: [
                            GlassDialogAction(
                              label: 'Share',
                              onPressed: () => _snack('Share'),
                            ),
                            const GlassDialogAction(
                              label: 'Delete',
                              role: GlassButtonRole.destructive,
                            ),
                          ],
                          cancel: const GlassDialogAction(
                            label: 'Cancel',
                            role: GlassButtonRole.cancel,
                          ),
                        ),
                        child: const Text('Action sheet'),
                      ),
                      GlassButton(
                        onPressed: () => showGlassFullScreenCover<void>(
                          context: context,
                          builder: (context) => Column(
                            children: [
                              Padding(
                                padding: const EdgeInsetsDirectional.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    const Spacer(),
                                    GlassButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Done'),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                'Cover',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                            ],
                          ),
                        ),
                        child: const Text('Full screen'),
                      ),
                      GlassPopoverAnchor(
                        popoverBuilder: (_) => const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Liquid Glass popover'),
                        ),
                        builder: (context, open) => GlassButton(
                          onPressed: open,
                          child: const Text('Popover'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  LiquidGlass(
                    shape: const GlassShape.rect(26),
                    padding: const EdgeInsetsDirectional.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text('Count ${_count.toInt()}')),
                            GlassStepper(
                              value: _count,
                              max: 10,
                              onChanged: (v) => setState(() => _count = v),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Expanded(child: Text('Period')),
                            GlassPicker<_Period>(
                              items: const [
                                GlassPickerItem(
                                  value: _Period.day,
                                  label: 'Day',
                                ),
                                GlassPickerItem(
                                  value: _Period.week,
                                  label: 'Week',
                                ),
                                GlassPickerItem(
                                  value: _Period.month,
                                  label: 'Month',
                                ),
                              ],
                              selected: _period,
                              onChanged: (p) => setState(() => _period = p),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GlassWheelPicker<_Period>(
                          items: const [
                            GlassPickerItem(value: _Period.day, label: 'Day'),
                            GlassPickerItem(value: _Period.week, label: 'Week'),
                            GlassPickerItem(
                              value: _Period.month,
                              label: 'Month',
                            ),
                          ],
                          selected: _period,
                          height: 128,
                          onChanged: (p) => setState(() => _period = p),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Expanded(child: Text('Date')),
                            GlassDatePicker(
                              value: _date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              onChanged: (d) => setState(() => _date = d),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Expanded(child: Text('Time')),
                            GlassDatePicker(
                              pickerMode: GlassDatePickerMode.time,
                              minuteInterval: 5,
                              value: _date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              onChanged: (d) => setState(() => _date = d),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GlassDatePicker(
                          style: GlassDatePickerStyle.wheel,
                          value: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          onChanged: (d) => setState(() => _date = d),
                        ),
                        const SizedBox(height: 12),
                        GlassButton(
                          onPressed: () async {
                            final range = await showGlassDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              helpText: 'Trip',
                            );
                            if (range != null) {
                              _snack(
                                '${range.start.month}/${range.start.day} - '
                                '${range.end.month}/${range.end.day}',
                              );
                            }
                          },
                          child: const Text('Date range'),
                        ),
                        const SizedBox(height: 12),
                        GlassColorPicker(
                          label: const Text('Accent'),
                          value: _accent,
                          onChanged: (c) => setState(() => _accent = c),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  GlassTextField(
                    placeholder: 'Email',
                    prefix: const Icon(CupertinoIcons.mail),
                    clearButton: true,
                    keyboardType: TextInputType.emailAddress,
                    errorText: _emailError,
                    onChanged: (v) => setState(
                      () => _emailError = v.isEmpty || v.contains('@')
                          ? null
                          : 'Enter a valid email',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const GlassTextField.password(
                    placeholder: 'Password',
                    prefix: Icon(CupertinoIcons.lock),
                  ),
                  const SizedBox(height: 12),
                  const GlassTextField(placeholder: 'Notes', maxLines: 4),
                  const SizedBox(height: 24),
                  Center(
                    child: GlassContextMenu(
                      items: [
                        GlassMenuItem(
                          label: 'Copy',
                          icon: CupertinoIcons.doc_on_doc,
                          onSelected: () => _snack('Copy'),
                        ),
                        GlassMenuItem(
                          label: 'Delete',
                          icon: CupertinoIcons.trash,
                          destructive: true,
                          onSelected: () => _snack('Delete'),
                        ),
                      ],
                      child: const LiquidGlass(
                        shape: GlassShape.rect(20),
                        padding: EdgeInsets.all(24),
                        child: Text('Long-press me'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  GlassListSection(
                    glass: Glass.regular,
                    margin: EdgeInsets.zero,
                    header: const Text('Settings'),
                    footer: const Text(
                      'A glass platter; omit glass for iOS cells.',
                    ),
                    children: [
                      GlassListTile(
                        leading: const Icon(CupertinoIcons.wifi),
                        title: const Text('Wi-Fi'),
                        trailing: GlassToggle(
                          value: _wifi,
                          onChanged: (v) => setState(() => _wifi = v),
                        ),
                      ),
                      GlassListTile(
                        leading: const Icon(CupertinoIcons.bluetooth),
                        title: const Text('Bluetooth'),
                        value: 'On',
                        chevron: true,
                        onTap: () => _snack('Bluetooth'),
                      ),
                      GlassListTile(
                        title: const Text('General'),
                        subtitle: const Text('About, storage, updates'),
                        chevron: true,
                        onTap: () => _snack('General'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GlassListSection(
                    header: const Text('Advanced'),
                    children: [
                      GlassDisclosureGroup(
                        leading: const Icon(CupertinoIcons.gear),
                        label: const Text('Advanced'),
                        isExpanded: _advanced,
                        onExpansionChanged: (v) =>
                            setState(() => _advanced = v),
                        children: const [
                          GlassListTile(title: Text('Proxy'), value: 'Off'),
                          GlassListTile(title: Text('DNS'), value: 'Automatic'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GlassListSection(
                    header: const Text('Picker styles'),
                    children: [
                      GlassPicker<_Period>(
                        style: GlassPickerStyle.navigationLink,
                        label: const Text('Period'),
                        items: _periods,
                        selected: _period,
                        onChanged: (p) => setState(() => _period = p),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GlassListSection(
                    header: const Text('Period'),
                    children: [
                      GlassPicker<_Period>(
                        style: GlassPickerStyle.inline,
                        items: _periods,
                        selected: _period,
                        onChanged: (p) => setState(() => _period = p),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in _tags.keys)
                        GlassChip(
                          label: tag,
                          icon: CupertinoIcons.tag,
                          selected: _tags[tag]!,
                          onSelected: (v) => setState(() => _tags[tag] = v),
                          onDeleted: () => setState(() => _tags.remove(tag)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      GlassLink(
                        destination: Uri.parse('https://flutter.dev'),
                        label: 'flutter.dev',
                        onOpen: (_) {},
                      ),
                      const SizedBox(width: 12),
                      GlassShareLink(onShare: () {}),
                      const SizedBox(width: 12),
                      GlassShareLink(label: 'Share', onShare: () {}),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GlassPhotosPicker(
                    label: 'Select Photos',
                    maxSelection: 0,
                    filter: GlassPhotosPickerFilter.any,
                    onPicked: (photos) => setState(() => _photos = photos),
                  ),
                  if (_photos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 72,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _photos.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _photos[i].isVideo
                              ? const ColoredBox(
                                  color: Colors.black54,
                                  child: SizedBox.square(
                                    dimension: 72,
                                    child: Icon(
                                      CupertinoIcons.videocam_fill,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : Image.file(
                                  File(_photos[i].path),
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  cacheWidth: 216,
                                ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Center(
                    child: GlassPageControl(
                      count: 4,
                      currentPage: _page,
                      onPageChanged: (p) => setState(() => _page = p),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: GlassProgressIndicator(value: _volume)),
                      const SizedBox(width: 16),
                      GlassProgressIndicator.circular(value: _volume),
                      const SizedBox(width: 16),
                      const GlassProgressIndicator.circular(),
                      const SizedBox(width: 16),
                      const GlassActivityIndicator(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GlassGauge(
                    value: _volume,
                    label: const Text('Battery'),
                    currentValueLabel: Text('${(_volume * 100).round()}%'),
                    minimumValueLabel: const Text('0'),
                    maximumValueLabel: const Text('100'),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GlassGauge(
                        value: _volume * 40,
                        min: 0,
                        max: 40,
                        style: GlassGaugeStyle.accessoryCircular,
                        label: const Text('Temp'),
                        currentValueLabel: Text('${(_volume * 40).round()}'),
                        minimumValueLabel: const Text('0'),
                        maximumValueLabel: const Text('40'),
                        tint: GlassSystemColors.orange,
                      ),
                      const SizedBox(width: 48),
                      GlassGauge(
                        value: _volume,
                        style: GlassGaugeStyle.accessoryCircularCapacity,
                        label: const Text('Battery'),
                        currentValueLabel: Text('${(_volume * 100).round()}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GlassBadge(
                        label: '3',
                        child: Icon(CupertinoIcons.mail, size: 28),
                      ),
                      SizedBox(width: 32),
                      GlassBadge(child: Icon(CupertinoIcons.bell, size: 28)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      GlassLabel.text(
                        text: 'Favourites',
                        icon: CupertinoIcons.heart,
                      ).glassEffect(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                      GlassLabel.text(
                        text: 'Share',
                        icon: CupertinoIcons.share,
                        layout: GlassLabelLayout.iconOnly,
                      ).glassEffect(padding: const EdgeInsets.all(10)),
                      GlassLabel.text(
                        text: 'Title only',
                        icon: CupertinoIcons.textformat,
                        layout: GlassLabelLayout.titleOnly,
                      ).glassEffect(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GlassEmptyState(
                    icon: const Icon(CupertinoIcons.tray),
                    title: const Text('No Mail'),
                    description: const Text(
                      'New messages you receive will appear here.',
                    ),
                    actions: [
                      GlassButton(
                        onPressed: () => _snack('Refresh'),
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  for (final name in _rows)
                    GlassSwipeActions(
                      key: ValueKey(name),
                      leading: [
                        GlassSwipeAction(
                          icon: CupertinoIcons.pin_fill,
                          label: 'Pin',
                          color: CupertinoColors.systemOrange,
                          onPressed: () => _snack('Pinned $name'),
                        ),
                      ],
                      trailing: [
                        GlassSwipeAction(
                          icon: CupertinoIcons.trash,
                          label: 'Delete',
                          color: CupertinoColors.systemRed,
                          onPressed: () => setState(() => _rows.remove(name)),
                        ),
                        GlassSwipeAction(
                          icon: CupertinoIcons.share,
                          label: 'Share',
                          color: CupertinoColors.systemBlue,
                          onPressed: () => _snack('Share $name'),
                        ),
                      ],
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.doc_text, size: 22),
                            const SizedBox(width: 12),
                            Expanded(child: Text(name)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 400),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

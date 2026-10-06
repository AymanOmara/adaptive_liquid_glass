import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart' show CupertinoColors, CupertinoIcons;
import 'package:flutter/material.dart';

/// `flutter run -t lib/components_demo.dart`: every component on one
/// `GlassScaffold`, over a photo. Add `--dart-define=MODE=shader` (or
/// `native`, `material`) to force a rendering path.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlass.precache();
  const mode = String.fromEnvironment('MODE');
  runApp(
    LiquidGlassTheme(
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
  bool _toolbar = false;
  double _count = 3;
  DateTime _date = DateTime(2026, 10, 6);
  final _rows = ['Copied Image', 'Meeting notes', 'Shopping list'];
  int _page = 0;
  final _tags = {'Travel': true, 'Food': false, 'Music': false};

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
        Image.asset('assets/backgrounds/photo.png', fit: BoxFit.cover),
        // The scaffold pads the body's MediaQuery by the bars; read it
        // below the scaffold, not with this State's context.
        Builder(
          builder: (context) => ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              20,
              16,
              20,
              24,
            ).add(MediaQuery.paddingOf(context)),
            children: [
              const GlassSearchField(),
              const SizedBox(height: 24),
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
                    Row(
                      children: [
                        const Expanded(child: Text('Toolbar instead of tabs')),
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
                        padding: EdgeInsetsDirectional.fromSTEB(24, 16, 24, 32),
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
                            GlassPickerItem(value: _Period.day, label: 'Day'),
                            GlassPickerItem(value: _Period.week, label: 'Week'),
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
                  ],
                ),
              ),
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
      ],
    ),
  );
}

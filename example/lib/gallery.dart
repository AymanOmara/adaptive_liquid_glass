import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

/// The README cookbook, one recipe per section, over a photo.
class Gallery extends StatelessWidget {
  /// Creates the gallery.
  const Gallery({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Gallery'),
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/backgrounds/photo.png', fit: BoxFit.cover),
          SafeArea(
            child: ListView(
              padding: const EdgeInsetsDirectional.all(20),
              children: const [
                _Recipe('Glass button', _GlassButton()),
                _Recipe('Card with padding', _Card()),
                _Recipe('Morphing pair (glassId)', _MorphingPair()),
                _Recipe('Merged union (unionId)', _Union()),
                _Recipe('Clear glass over media', _ClearOverMedia()),
                _Recipe('Tinted glass', _Tinted()),
                _Recipe('Tab bar', _TabBar()),
                _Recipe('Five tabs, badges, active icons', _FiveTabs()),
                _Recipe('Buttons (GlassButton)', _Buttons()),
                _Recipe('Navigation bar', _NavBarDemo()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled gallery section.
class _Recipe extends StatelessWidget {
  const _Recipe(this.title, this.child);

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(blurRadius: 4)],
          ),
        ),
        const SizedBox(height: 12),
        Center(child: child),
      ],
    ),
  );
}

void _snack(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

class _GlassButton extends StatelessWidget {
  const _GlassButton();

  @override
  Widget build(BuildContext context) =>
      const Text('Continue', style: TextStyle(fontSize: 17)).glassEffect(
        onPressed: () => _snack(context, 'Pressed'),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 24,
          vertical: 14,
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card();

  @override
  Widget build(BuildContext context) => const LiquidGlass(
    shape: GlassShape.rect(24),
    padding: EdgeInsetsDirectional.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Liquid Glass',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 6),
        Text('Text and icons on glass pick a readable colour.'),
      ],
    ),
  );
}

class _MorphingPair extends StatefulWidget {
  const _MorphingPair();

  @override
  State<_MorphingPair> createState() => _MorphingPairState();
}

class _MorphingPairState extends State<_MorphingPair> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => GlassGroup(
    spacing: 20,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        LiquidGlass(
          glassId: 'toggle',
          shape: const GlassShape.circle(),
          padding: const EdgeInsetsDirectional.all(14),
          onPressed: () => setState(() => _expanded = !_expanded),
          child: Icon(_expanded ? Icons.close : Icons.add),
        ),
        if (_expanded)
          const LiquidGlass(
            glassId: 'extra',
            shape: GlassShape.circle(),
            padding: EdgeInsetsDirectional.all(14),
            child: Icon(Icons.favorite),
          ),
      ],
    ),
  );
}

class _Union extends StatelessWidget {
  const _Union();

  @override
  Widget build(BuildContext context) => GlassGroup(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 24,
      children: [
        for (final icon in [Icons.edit, Icons.share, Icons.delete])
          Icon(icon).glassEffect(
            shape: const GlassShape.circle(),
            unionId: 'tools',
            padding: const EdgeInsetsDirectional.all(12),
          ),
      ],
    ),
  );
}

class _ClearOverMedia extends StatelessWidget {
  const _ClearOverMedia();

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: SizedBox(
      height: 180,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/backgrounds/gradient.png', fit: BoxFit.cover),
          Center(
            child: const Icon(Icons.play_arrow, size: 36).glassEffect(
              glass: Glass.clear.interactive(),
              shape: const GlassShape.circle(),
              padding: const EdgeInsetsDirectional.all(16),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Tinted extends StatelessWidget {
  const _Tinted();

  @override
  Widget build(BuildContext context) => LiquidGlass(
    glass: Glass.regular.tint(Colors.blue),
    onPressed: () => _snack(context, 'Tinted'),
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: 24,
      vertical: 14,
    ),
    child: const Text('Tinted', style: TextStyle(fontSize: 17)),
  );
}

class _TabBar extends StatefulWidget {
  const _TabBar();

  @override
  State<_TabBar> createState() => _TabBarState();
}

class _TabBarState extends State<_TabBar> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => GlassTabBar(
    items: const [
      GlassTabBarItem(icon: CupertinoIcons.clock_fill, label: 'History'),
      GlassTabBarItem(
        icon: CupertinoIcons.text_quote,
        label: 'Snippets',
        badge: '3',
      ),
      GlassTabBarItem(icon: CupertinoIcons.gear_solid, label: 'Settings'),
    ],
    selectedIndex: _tab,
    onSelected: (i) => setState(() => _tab = i),
  );
}

class _FiveTabs extends StatefulWidget {
  const _FiveTabs();

  @override
  State<_FiveTabs> createState() => _FiveTabsState();
}

class _FiveTabsState extends State<_FiveTabs> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => GlassTabBar(
    items: const [
      GlassTabBarItem(
        icon: CupertinoIcons.house,
        activeIcon: CupertinoIcons.house_fill,
        label: 'Home',
      ),
      GlassTabBarItem(icon: CupertinoIcons.search, label: 'Search'),
      GlassTabBarItem(
        icon: CupertinoIcons.mail,
        activeIcon: CupertinoIcons.mail_solid,
        label: 'Inbox',
        badge: '12',
      ),
      GlassTabBarItem(
        icon: CupertinoIcons.bell,
        activeIcon: CupertinoIcons.bell_fill,
        label: 'Alerts',
        badge: '',
      ),
      GlassTabBarItem(
        icon: CupertinoIcons.person,
        activeIcon: CupertinoIcons.person_fill,
        label: 'Profile',
      ),
    ],
    selectedIndex: _tab,
    onSelected: (i) => setState(() => _tab = i),
  );
}

class _Buttons extends StatelessWidget {
  const _Buttons();

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      for (final size in [
        GlassControlSize.small,
        GlassControlSize.regular,
        GlassControlSize.large,
      ])
        GlassButton(onPressed: () {}, size: size, child: Text(size.name)),
      GlassButton(
        onPressed: () {},
        style: GlassButtonStyle.glassProminent,
        child: const Text('Prominent'),
      ),
      GlassButton(
        onPressed: () {},
        role: GlassButtonRole.destructive,
        child: const Text('Delete'),
      ),
      const GlassButton(onPressed: null, child: Text('Disabled')),
      GlassButton(onPressed: () {}, loading: true, child: const Text('Saving')),
      GlassButton.icon(
        onPressed: () {},
        icon: CupertinoIcons.share,
        semanticLabel: 'Share',
      ),
      GlassButton.icon(
        onPressed: () {},
        icon: CupertinoIcons.add,
        label: const Text('New'),
      ),
    ],
  );
}

class _NavBarDemo extends StatelessWidget {
  const _NavBarDemo();

  @override
  Widget build(BuildContext context) => GlassButton(
    onPressed: () => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const _LargeTitlePage())),
    child: const Text('Open a large-title page'),
  );
}

class _LargeTitlePage extends StatelessWidget {
  const _LargeTitlePage();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverGlassNavigationBar(
          largeTitle: const Text('Inbox'),
          actions: [
            GlassButton.icon(
              onPressed: () {},
              icon: CupertinoIcons.square_pencil,
              semanticLabel: 'Compose',
            ),
            GlassButton.icon(
              onPressed: () {},
              icon: CupertinoIcons.ellipsis,
              semanticLabel: 'More',
            ),
          ],
        ),
        SliverList.builder(
          itemCount: 60,
          itemBuilder: (_, i) => SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('Row $i'),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

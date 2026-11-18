// অ্যাপের মূল কাঠামো: ব্যাকগ্রাউন্ড + ৫টি ট্যাব + নিচের কাচের নেভিগেশন বার।

import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../ui/components.dart';
import 'home_page.dart';
import 'more_page.dart';
import 'system_page.dart';
import 'themes_page.dart';
import 'wallpaper_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // অ্যাপ বন্ধ থাকার সময় অটো-চেঞ্জার / উইজেট ওয়ালপেপার বদলে থাকতে পারে
    if (state == AppLifecycleState.resumed) context.appRead.refreshCurrentWallpaper();
  }

  void go(int i) => setState(() => index = i);

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final pages = [
      HomePage(onNavigate: go),
      const WallpaperPage(),
      const ThemesPage(),
      const SystemPage(),
      const MorePage(),
    ];
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) go(0);
      },
      child: Stack(children: [
        const Positioned.fill(child: AppBackground()),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          body: AnimatedSwitcher(
            duration: look.anim(260),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(key: ValueKey(index), child: pages[index]),
          ),
          bottomNavigationBar: _GlassNavBar(index: index, onTap: go),
        ),
      ]),
    );
  }
}

class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_rounded, 'nav_home'),
    (Icons.wallpaper_rounded, 'nav_wallpapers'),
    (Icons.palette_rounded, 'nav_themes'),
    (Icons.memory_rounded, 'nav_system'),
    (Icons.grid_view_rounded, 'nav_more'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final look = context.look;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottom + 10),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: p.popupFill.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(look.radius + 6),
          border: Border.all(color: p.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(look.radius),
                onTap: () => onTap(i),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  AnimatedContainer(
                    duration: look.anim(220),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: i == index ? LinearGradient(colors: [p.buttonTop, p.buttonBottom]) : null,
                      boxShadow: i == index && look.glow > 0
                          ? [BoxShadow(color: p.glow.withValues(alpha: 0.35 * look.glow), blurRadius: 12 * look.glow)]
                          : null,
                    ),
                    child: Icon(_items[i].$1, size: 22, color: i == index ? p.onAccent : p.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t(_items[i].$2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: i == index ? p.accentText : p.textMuted,
                      fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

/// ট্যাব পেজের নিচে নেভিগেশন বারের জন্য ফাঁকা জায়গা
double navBarSpace(BuildContext context) => MediaQuery.paddingOf(context).bottom + 96;

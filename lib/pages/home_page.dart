// হোম (ড্যাশবোর্ড): শুভেচ্ছা, ঘড়ি, ব্যাটারি/RAM/স্টোরেজ, বর্তমান ওয়ালপেপার, দ্রুত কাজ।

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/app_info.dart';
import '../core/i18n.dart';
import '../services/native.dart';
import '../ui/components.dart';
import 'backup_page.dart';
import 'shell.dart';
import 'widgets_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic> battery = {};
  Map<String, dynamic> memory = {};
  Map<String, dynamic>? internal;
  Timer? timer;
  bool nextBusy = false;

  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    final b = await Native.battery();
    final m = await Native.memory();
    final s = await Native.storage();
    if (!mounted) return;
    setState(() {
      battery = b;
      memory = m;
      internal = s.isEmpty ? null : s.first;
    });
  }

  Future<void> next() async {
    setState(() => nextBusy = true);
    final ok = await context.appRead.nextWallpaper();
    if (!mounted) return;
    setState(() => nextBusy = false);
    showToast(context, ok ? t('wp_set_ok') : t('wp_set_fail'), error: !ok);
  }

  String greeting() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return t('greet_morning');
    if (h >= 12 && h < 17) return t('greet_afternoon');
    if (h >= 17 && h < 21) return t('greet_evening');
    return t('greet_night');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = app.palette;
    final top = MediaQuery.paddingOf(context).top;

    final level = (battery['level'] as num?)?.toInt() ?? -1;
    final charging = battery['charging'] == true;
    final memTotal = (memory['total'] as num?)?.toDouble() ?? 0;
    final memAvail = (memory['available'] as num?)?.toDouble() ?? 0;
    final memUsed = memTotal > 0 ? (memTotal - memAvail) / memTotal : 0.0;
    final stTotal = (internal?['total'] as num?)?.toDouble() ?? 0;
    final stFree = (internal?['free'] as num?)?.toDouble() ?? 0;
    final freePct = stTotal > 0 ? stFree / stTotal * 100 : 100.0;
    final current = app.currentItem;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, top + 14, 16, navBarSpace(context)),
      children: [
        // ---- মাথা ----
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(greeting(), style: TextStyle(color: p.textMuted, fontSize: 15)),
              ShaderMask(
                shaderCallback: (r) => LinearGradient(colors: [p.accentLight, p.accent, p.accent2]).createShader(r),
                child: const Text(appName,
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
              ),
            ]),
          ),
          _RoundIcon(
            icon: p.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            tooltip: p.dark ? t('mode_light') : t('mode_dark'),
            onTap: () => app.setDark(!app.dark),
          ),
        ]),
        const SizedBox(height: 16),

        // ---- ঘড়ি ----
        GlassCard(
          active: true,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Row(children: [
            const Expanded(child: _LiveClock()),
            Icon(Icons.auto_awesome_rounded, color: p.accent, size: 34),
          ]),
        ),
        const SizedBox(height: 12),

        // ---- তিনটি ছোট পরিসংখ্যান ----
        Row(children: [
          Expanded(
            child: _MiniStat(
              icon: charging ? Icons.battery_charging_full_rounded : Icons.battery_5_bar_rounded,
              label: t('battery'),
              value: level >= 0 ? '$level%' : '—',
              progress: level >= 0 ? level / 100 : 0,
              color: level >= 0 && level <= 15 && !charging ? const Color(0xFFFF4D4F) : p.accent,
              onTap: () => widget.onNavigate(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MiniStat(
              icon: Icons.memory_rounded,
              label: t('ram'),
              value: memTotal > 0 ? '${(memUsed * 100).round()}%' : '—',
              progress: memUsed,
              color: p.accent2,
              onTap: () => widget.onNavigate(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MiniStat(
              icon: Icons.sd_storage_rounded,
              label: t('free_space'),
              value: stTotal > 0 ? formatBytes(stFree) : '—',
              progress: stTotal > 0 ? 1 - stFree / stTotal : 0,
              color: storageColor(app, freePct),
              onTap: () => widget.onNavigate(3),
            ),
          ),
        ]),

        // ---- বর্তমান ওয়ালপেপার ----
        SectionTitle(t('home_current_wp')),
        GlassCard(
          onTap: () => widget.onNavigate(1),
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(context.look.radius * 0.7),
              child: SizedBox(
                width: 78,
                height: 128,
                child: current != null
                    ? Image.file(File(current.path), fit: BoxFit.cover, cacheWidth: 240, gaplessPlayback: true)
                    : ColoredBox(color: p.glassInput, child: Icon(Icons.image_outlined, color: p.textMuted)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(current != null ? wallpaperName(current.id, current.bundled) : t('home_no_wp'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  app.autoEnabled
                      ? tf('home_auto_on', {'t': formatInterval(app.autoMinutes)})
                      : t('home_auto_off'),
                  style: TextStyle(color: p.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (app.autoPool.isNotEmpty)
                    GlowButton(
                      label: t('wp_next'),
                      icon: Icons.skip_next_rounded,
                      compact: true,
                      busy: nextBusy,
                      onPressed: next,
                    ),
                  GlowButton(
                    label: t('home_change'),
                    icon: Icons.photo_library_rounded,
                    compact: true,
                    primary: false,
                    onPressed: () => widget.onNavigate(1),
                  ),
                ]),
              ]),
            ),
          ]),
        ),

        // ---- দ্রুত কাজ ----
        SectionTitle(t('home_quick')),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.1,
          children: [
            _QuickAction(Icons.wallpaper_rounded, t('nav_wallpapers'), () => widget.onNavigate(1)),
            _QuickAction(Icons.palette_rounded, t('nav_themes'), () => widget.onNavigate(2)),
            _QuickAction(Icons.widgets_rounded, t('widget_title'),
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WidgetsPage()))),
            _QuickAction(Icons.backup_rounded, t('backup_title'),
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupPage()))),
          ],
        ),
      ],
    );
  }
}

class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late Timer timer;
  DateTime now = DateTime.now();

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => now = DateTime.now()));
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text(formatTime(now, use24),
            style: TextStyle(color: p.text, fontSize: 46, fontWeight: FontWeight.w800, height: 1.05)),
        if (!use24) ...[
          const SizedBox(width: 6),
          Text(amPm(now), style: TextStyle(color: p.accentText, fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ]),
      const SizedBox(height: 4),
      Text(formatDate(now), style: TextStyle(color: p.textMuted, fontSize: 15)),
    ]);
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label, value;
  final double progress;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.textMuted, fontSize: 12)),
        const SizedBox(height: 8),
        GlassBar(value: progress, color: color, height: 5),
      ]),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        IconBadge(icon, size: 38),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.text, fontWeight: FontWeight.w600, fontSize: 14)),
        ),
      ]),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap, required this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: p.glassStrong,
        shape: CircleBorder(side: BorderSide(color: p.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(11), child: Icon(icon, color: p.accent, size: 22)),
        ),
      ),
    );
  }
}

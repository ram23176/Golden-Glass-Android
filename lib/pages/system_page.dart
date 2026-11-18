// সিস্টেম: ব্যাটারি, RAM, স্টোরেজ (Internal + SD কার্ড/USB), ডিভাইসের তথ্য।
// (Windows ভার্সনের Drive Monitor + System Monitor-এর Android রূপ)

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../services/native.dart';
import '../ui/components.dart';
import 'shell.dart';

class SystemPage extends StatefulWidget {
  const SystemPage({super.key});

  @override
  State<SystemPage> createState() => _SystemPageState();
}

class _SystemPageState extends State<SystemPage> {
  Map<String, dynamic> battery = {};
  Map<String, dynamic> memory = {};
  Map<String, dynamic> device = {};
  List<Map<String, dynamic>> volumes = [];
  Timer? timer;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    final results = await Future.wait([Native.battery(), Native.memory(), Native.deviceInfo(), Native.storage()]);
    if (!mounted) return;
    setState(() {
      battery = results[0] as Map<String, dynamic>;
      memory = results[1] as Map<String, dynamic>;
      device = results[2] as Map<String, dynamic>;
      volumes = results[3] as List<Map<String, dynamic>>;
      loaded = true;
    });
  }

  void editBands() {
    showModalBottomSheet(context: context, useSafeArea: true, builder: (_) => const _BandSheet());
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = app.palette;
    final top = MediaQuery.paddingOf(context).top;

    final level = (battery['level'] as num?)?.toInt() ?? -1;
    final charging = battery['charging'] == true;
    final temp = (battery['temperature'] as num?)?.toDouble();
    final volt = (battery['voltage'] as num?)?.toInt();
    final memTotal = (memory['total'] as num?)?.toDouble() ?? 0;
    final memAvail = (memory['available'] as num?)?.toDouble() ?? 0;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, top + 14, 16, navBarSpace(context)),
      children: [
        Text(t('nav_system'), style: TextStyle(color: p.text, fontSize: 26, fontWeight: FontWeight.w800)),
        Text(t('sys_sub'), style: TextStyle(color: p.textMuted, fontSize: 13.5)),

        // ---- ব্যাটারি ----
        SectionTitle(t('battery')),
        GlassCard(
          active: charging,
          child: Row(children: [
            _Ring(
              value: level >= 0 ? level / 100 : 0,
              color: level >= 0 && level <= 15 && !charging ? const Color(0xFFFF4D4F) : p.accent,
              center: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(charging ? Icons.bolt_rounded : Icons.battery_std_rounded, color: p.accent, size: 20),
                Text(level >= 0 ? '$level%' : '—',
                    style: TextStyle(color: p.text, fontSize: 20, fontWeight: FontWeight.w800)),
              ]),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(children: [
                InfoRow(t('bat_state'), t(battery['full'] == true
                    ? 'bat_full'
                    : charging
                        ? 'bat_charging'
                        : 'bat_discharging')),
                InfoRow(t('bat_source'), t('plug_${battery['plugged'] ?? 'none'}')),
                InfoRow(t('bat_health'), t('health_${battery['health'] ?? 'unknown'}')),
                if (temp != null) InfoRow(t('bat_temp'), '${temp.toStringAsFixed(1)} °C'),
                if (volt != null) InfoRow(t('bat_voltage'), '${(volt / 1000).toStringAsFixed(2)} V'),
              ]),
            ),
          ]),
        ),

        // ---- RAM ----
        SectionTitle(t('ram')),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconBadge(Icons.memory_rounded, color: p.accent2),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  memTotal > 0
                      ? tf('used_of', {'u': formatBytes(memTotal - memAvail), 't': formatBytes(memTotal)})
                      : '—',
                  style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Text(memTotal > 0 ? '${((memTotal - memAvail) / memTotal * 100).round()}%' : '',
                  style: TextStyle(color: p.accentText, fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
            const SizedBox(height: 12),
            GlassBar(value: memTotal > 0 ? (memTotal - memAvail) / memTotal : 0, color: p.accent2),
            const SizedBox(height: 8),
            Text(tf('ram_available', {'n': formatBytes(memAvail)}), style: TextStyle(color: p.textMuted, fontSize: 13)),
            if (memory['low'] == true)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(t('ram_low'), style: const TextStyle(color: Color(0xFFFFB020), fontSize: 13)),
              ),
          ]),
        ),

        // ---- স্টোরেজ ----
        SectionTitle(
          t('storage'),
          trailing: TextButton.icon(
            onPressed: editBands,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: Text(t('st_colors')),
          ),
        ),
        if (loaded && volumes.isEmpty) GlassCard(child: Text(t('st_none'), style: TextStyle(color: p.textMuted))),
        for (final v in volumes) ...[_VolumeCard(volume: v), const SizedBox(height: 10)],
        Text(t('st_note'), style: TextStyle(color: p.textMuted, fontSize: 12)),

        // ---- ডিভাইস ----
        SectionTitle(t('device')),
        GlassCard(
          child: Column(children: [
            InfoRow(t('dev_model'), '${device['manufacturer'] ?? ''} ${device['model'] ?? ''}'.trim()),
            InfoRow(t('dev_android'), device['android'] != null ? 'Android ${device['android']} (API ${device['sdk']})' : '—'),
            InfoRow(t('dev_cores'), '${device['cores'] ?? '—'}'),
            InfoRow(t('dev_abi'), '${device['abi'] ?? '—'}'),
            InfoRow(t('dev_screen'), '${device['screen'] ?? '—'}'),
            InfoRow(t('dev_uptime'), device['uptimeMs'] is num ? formatUptime((device['uptimeMs'] as num).toInt()) : '—'),
          ]),
        ),
      ],
    );
  }
}

class _VolumeCard extends StatelessWidget {
  const _VolumeCard({required this.volume});

  final Map<String, dynamic> volume;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = app.palette;
    final total = (volume['total'] as num?)?.toDouble() ?? 0;
    final free = (volume['free'] as num?)?.toDouble() ?? 0;
    final freePct = total > 0 ? free / total * 100 : 0.0;
    final color = storageColor(app, freePct);
    final kind = volume['kind'] as String? ?? 'other';
    final label = volume['label'] as String?;
    final title = kind == 'internal' ? t('st_internal') : (label ?? t(kind == 'removable' ? 'st_removable' : 'st_other'));
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconBadge(kind == 'internal' ? Icons.smartphone_rounded : Icons.sd_card_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w700)),
              Text(tf('used_of', {'u': formatBytes(total - free), 't': formatBytes(total)}),
                  style: TextStyle(color: p.textMuted, fontSize: 13)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(formatBytes(free), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
            Text(t('st_free'), style: TextStyle(color: p.textMuted, fontSize: 12)),
          ]),
        ]),
        const SizedBox(height: 12),
        GlassBar(value: total > 0 ? 1 - free / total : 0, color: color),
        const SizedBox(height: 6),
        Text(tf('st_free_pct', {'n': freePct.toStringAsFixed(0)}), style: TextStyle(color: p.textMuted, fontSize: 12.5)),
      ]),
    );
  }
}

class _BandSheet extends StatelessWidget {
  const _BandSheet();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = app.palette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('st_colors'), style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(t('st_colors_sub'), style: TextStyle(color: p.textMuted, fontSize: 13)),
          SliderRow(
            label: t('st_warn'),
            value: app.storageWarn,
            min: 5,
            max: 50,
            divisions: 45,
            format: (v) => '< ${v.round()}%',
            onChanged: (v) => app.setStorageBands(v.roundToDouble(), math.min(app.storageCritical, v - 1)),
          ),
          SliderRow(
            label: t('st_critical'),
            value: app.storageCritical,
            min: 1,
            max: 49,
            divisions: 48,
            format: (v) => '< ${v.round()}%',
            onChanged: (v) => app.setStorageBands(math.max(app.storageWarn, v + 1), v.roundToDouble()),
          ),
          Row(children: [
            _Legend(const Color(0xFF34D399), t('st_ok')),
            _Legend(const Color(0xFFFFB020), t('st_warn_short')),
            _Legend(const Color(0xFFFF4D4F), t('st_critical_short')),
          ]),
        ]),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: context.pal.textMuted, fontSize: 13)),
      ]),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.value, required this.color, required this.center});

  final double value;
  final Color color;
  final Widget center;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return SizedBox(
      width: 104,
      height: 104,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value),
        duration: context.look.anim(700),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => CustomPaint(
          painter: _RingPainter(v, color, p.track),
          child: Center(child: child),
        ),
        child: center,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color, this.track);

  final double value;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.09;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(r, 0, math.pi * 2, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = track);
    canvas.drawArc(
        r,
        -math.pi / 2,
        math.pi * 2 * value.clamp(0, 1),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            colors: [Color.lerp(color, Colors.white, 0.3)!, color],
            transform: const GradientRotation(-math.pi / 2),
          ).createShader(rect));
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color || old.track != track;
}

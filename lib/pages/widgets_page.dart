// হোম স্ক্রিন উইজেট: প্রিভিউ + "হোম স্ক্রিনে যোগ করুন" বাটন + নির্দেশনা।

import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../services/native.dart';
import '../ui/components.dart';

class WidgetsPage extends StatefulWidget {
  const WidgetsPage({super.key});

  @override
  State<WidgetsPage> createState() => _WidgetsPageState();
}

class _WidgetsPageState extends State<WidgetsPage> with WidgetsBindingObserver {
  int count = 0;
  bool canPin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load();
  }

  Future<void> load() async {
    final c = await Native.widgetCount();
    final pin = await Native.canPinWidget();
    if (mounted) {
      setState(() {
        count = c;
        canPin = pin;
      });
    }
  }

  Future<void> pin() async {
    await context.appRead.syncNative();
    final ok = await Native.pinWidget();
    if (!mounted) return;
    if (!ok) showToast(context, t('widget_pin_fail'), error: true);
    Future.delayed(const Duration(seconds: 2), load);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return GlassPage(
      title: t('widget_title'),
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        Text(t('widget_preview'), style: TextStyle(color: p.textMuted, fontSize: 13)),
        const SizedBox(height: 8),
        const _WidgetPreview(),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconBadge(count > 0 ? Icons.check_rounded : Icons.widgets_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(count > 0 ? tf('widget_count', {'n': '$count'}) : t('widget_none'),
                    style: TextStyle(color: p.text, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ]),
            const SizedBox(height: 14),
            if (canPin)
              SizedBox(
                width: double.infinity,
                child: GlowButton(label: t('widget_add'), icon: Icons.add_to_home_screen_rounded, onPressed: pin),
              ),
          ]),
        ),
        SectionTitle(t('widget_manual')),
        GlassCard(
          child: Text(t('widget_steps'), style: TextStyle(color: p.text, height: 1.6)),
        ),
        SectionTitle(t('widget_features')),
        GlassCard(
          child: Text(t('widget_feature_list'), style: TextStyle(color: p.text, height: 1.6)),
        ),
      ]),
    );
  }
}

/// উইজেট দেখতে কেমন — native layout (widget_glass_clock.xml)-এর Flutter নকল
class _WidgetPreview extends StatelessWidget {
  const _WidgetPreview();

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final now = DateTime.now();
    final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
    const text = Color(0xFFFFF7E8);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xE0332443), Color(0xE014101F)],
        ),
        border: Border.all(color: const Color(0x66FFBF4D), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(formatTime(now, use24),
                style: TextStyle(color: p.accent, fontSize: 44, fontWeight: FontWeight.bold, height: 1)),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(color: const Color(0x40FFBF4D)),
            ),
            child: Icon(Icons.skip_next_rounded, color: p.accent),
          ),
        ]),
        const SizedBox(height: 2),
        Text(formatDate(now), style: TextStyle(color: text.withValues(alpha: 0.9), fontSize: 14)),
        Container(margin: const EdgeInsets.symmetric(vertical: 8), width: 48, height: 2, color: p.accent),
        Text('🔋 85%     💾 42.5 GB ${t('w_free')}', style: TextStyle(color: text.withValues(alpha: 0.8), fontSize: 13)),
      ]),
    );
  }
}

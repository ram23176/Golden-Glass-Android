// Appearance: কার্ডের স্বচ্ছতা, কোণের গোলভাব, আলোর আভা, অ্যানিমেশনের গতি, ব্যাকগ্রাউন্ড ঝাপসা।

import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/palette.dart';
import '../ui/components.dart';

class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = app.palette;
    final look = app.look;
    return GlassPage(
      title: t('appearance_title'),
      actions: [
        TextButton(
          onPressed: () => app.setLook(const Appearance()),
          child: Text(t('reset')),
        ),
      ],
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        // লাইভ প্রিভিউ
        GlassCard(
          active: true,
          child: Row(children: [
            const IconBadge(Icons.auto_awesome_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('ap_preview'), style: TextStyle(color: p.text, fontWeight: FontWeight.w700, fontSize: 16)),
                Text(t('ap_preview_sub'), style: TextStyle(color: p.textMuted, fontSize: 13)),
              ]),
            ),
            GlowButton(label: t('ok'), compact: true, onPressed: () {}),
          ]),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(children: [
            SliderRow(
              label: t('ap_opacity'),
              value: look.cardOpacity,
              min: 0.30,
              max: 0.95,
              divisions: 13,
              format: (v) => '${(v * 100).round()}%',
              onChanged: (v) => app.setLook(look.copyWith(cardOpacity: v)),
            ),
            SliderRow(
              label: t('ap_radius'),
              value: look.radius,
              min: 6,
              max: 28,
              divisions: 22,
              format: (v) => '${v.round()} dp',
              onChanged: (v) => app.setLook(look.copyWith(radius: v.roundToDouble())),
            ),
            SliderRow(
              label: t('ap_glow'),
              value: look.glow,
              min: 0,
              max: 1.5,
              divisions: 15,
              format: (v) => v == 0 ? t('off') : '${(v * 100).round()}%',
              onChanged: (v) => app.setLook(look.copyWith(glow: v)),
            ),
            SliderRow(
              label: t('ap_speed'),
              value: look.animSpeed,
              min: 0.5,
              max: 2,
              divisions: 6,
              format: (v) => '${v.toStringAsFixed(2).replaceAll(RegExp(r'0$'), '')}×',
              onChanged: (v) => app.setLook(look.copyWith(animSpeed: v)),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(children: [
            SwitchRow(
              icon: Icons.wallpaper_rounded,
              title: t('ap_wp_bg'),
              subtitle: t('ap_wp_bg_sub'),
              value: look.wallpaperBackground,
              onChanged: (v) => app.setLook(look.copyWith(wallpaperBackground: v)),
            ),
            if (look.wallpaperBackground)
              SliderRow(
                label: t('ap_blur'),
                value: look.blur,
                min: 0,
                max: 40,
                divisions: 20,
                format: (v) => v == 0 ? t('off') : '${v.round()}',
                onChanged: (v) => app.setLook(look.copyWith(blur: v.roundToDouble())),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        Text(t('ap_note'), style: TextStyle(color: p.textMuted, fontSize: 12.5)),
      ]),
    );
  }
}

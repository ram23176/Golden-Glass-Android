// সেটিংস ও অ্যাপ পরিচিতি।

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_info.dart';
import '../core/i18n.dart';
import '../ui/components.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = app.palette;
    return GlassPage(
      title: t('settings_title'),
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const IconBadge(Icons.translate_rounded, size: 38),
              const SizedBox(width: 12),
              Expanded(child: Text(t('set_language'), style: TextStyle(color: p.text, fontWeight: FontWeight.w600))),
              ChoiceRow<String>(
                options: const ['bn', 'en'],
                value: app.lang,
                label: (l) => l == 'bn' ? 'বাংলা' : 'English',
                onChanged: app.setLang,
              ),
            ]),
            Divider(color: p.divider, height: 24),
            SwitchRow(
              icon: Icons.dark_mode_rounded,
              title: t('mode_dark'),
              value: app.dark,
              onChanged: app.setDark,
            ),
          ]),
        ),
        SectionTitle(t('about_title')),
        GlassCard(
          child: Column(children: [
            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset('assets/images/logo.png', width: 64, height: 64),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(appName, style: TextStyle(color: p.text, fontSize: 20, fontWeight: FontWeight.w800)),
                  Text(tf('about_version', {'v': appVersion}), style: TextStyle(color: p.textMuted)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Text(t('about_text'), style: TextStyle(color: p.text, height: 1.5)),
            Divider(color: p.divider, height: 24),
            InfoRow(t('about_license'), 'MIT'),
            InfoRow(t('about_platform'), 'Android 8.0+'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Text(appRepoUrl,
                    style: TextStyle(color: p.accentText, fontSize: 12.5), overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                tooltip: t('copy'),
                icon: Icon(Icons.copy_rounded, color: p.accent, size: 20),
                onPressed: () async {
                  await Clipboard.setData(const ClipboardData(text: appRepoUrl));
                  if (context.mounted) showToast(context, t('copied'));
                },
              ),
            ]),
            Text(t('about_credits'), style: TextStyle(color: p.textMuted, fontSize: 12.5, height: 1.5)),
          ]),
        ),
        const SizedBox(height: 18),
        GlowButton(
          label: t('set_reset'),
          icon: Icons.restart_alt_rounded,
          primary: false,
          danger: true,
          onPressed: () async {
            if (await confirm(context, t('set_reset'), t('set_reset_msg'), danger: true, ok: t('reset'))) {
              app.resetToDefaults();
              if (context.mounted) showToast(context, t('set_reset_done'));
            }
          },
        ),
      ]),
    );
  }
}

// "আরও" ট্যাব: বাকি সব পেজে যাওয়ার তালিকা।

import 'package:flutter/material.dart';

import '../core/app_info.dart';
import '../core/i18n.dart';
import '../ui/components.dart';
import 'appearance_page.dart';
import 'backup_page.dart';
import 'settings_page.dart';
import 'shell.dart';
import 'widgets_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final top = MediaQuery.paddingOf(context).top;
    void open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    final entries = [
      (Icons.blur_on_rounded, 'appearance_title', 'appearance_sub', () => open(const AppearancePage())),
      (Icons.widgets_rounded, 'widget_title', 'widget_sub', () => open(const WidgetsPage())),
      (Icons.backup_rounded, 'backup_title', 'backup_sub', () => open(const BackupPage())),
      (Icons.settings_rounded, 'settings_title', 'settings_sub', () => open(const SettingsPage())),
    ];
    return ListView(
      padding: EdgeInsets.fromLTRB(16, top + 14, 16, navBarSpace(context)),
      children: [
        Text(t('nav_more'), style: TextStyle(color: p.text, fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        for (final e in entries) ...[
          GlassCard(
            onTap: e.$4,
            child: Row(children: [
              IconBadge(e.$1),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t(e.$2), style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(t(e.$3), style: TextStyle(color: p.textMuted, fontSize: 13)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: p.textMuted),
            ]),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        Center(
          child: Text('$appName $appVersion · Android',
              style: TextStyle(color: p.textMuted, fontSize: 12.5)),
        ),
      ],
    );
  }
}

// ব্যাকআপ ও রিস্টোর: সব সেটিংস একটি .json ফাইলে সংরক্ষণ / ফেরত আনা।

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../ui/components.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool busy = false;

  Future<void> export() async {
    setState(() => busy = true);
    try {
      final now = DateTime.now();
      final stamp =
          '${now.year}-${twoDigits(now.month)}-${twoDigits(now.day)}_${twoDigits(now.hour)}${twoDigits(now.minute)}';
      final uri = await FilePicker.saveFile(
        fileName: 'GoldenGlass-Android-$stamp.json',
        bytes: utf8.encode(context.appRead.exportBackup()),
        mimeType: 'application/json',
      );
      if (uri != null && mounted) showToast(context, t('bk_saved'));
    } catch (_) {
      if (mounted) showToast(context, t('save_fail'), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> restore() async {
    final app = context.appRead;
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null || !mounted) return;
    if (!await confirm(context, t('bk_restore_title'), t('bk_restore_msg'), ok: t('bk_restore'))) return;
    setState(() => busy = true);
    try {
      final size = await file.length() ?? 0;
      if (size > 2 * 1024 * 1024) throw const FormatException('bk_err_file');
      await app.importBackup(await file.readAsBytes());
      if (mounted) showToast(context, t('bk_restored'));
    } on FormatException catch (e) {
      if (mounted) showToast(context, t(e.message), error: true);
    } catch (_) {
      if (mounted) showToast(context, t('bk_err_file'), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return GlassPage(
      title: t('backup_title'),
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const IconBadge(Icons.save_alt_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(t('bk_export'), style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(t('bk_export_sub'), style: TextStyle(color: p.textMuted, fontSize: 13.5, height: 1.5)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: GlowButton(label: t('bk_export_btn'), icon: Icons.download_rounded, busy: busy, onPressed: export),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const IconBadge(Icons.restore_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(t('bk_restore'), style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(t('bk_restore_sub'), style: TextStyle(color: p.textMuted, fontSize: 13.5, height: 1.5)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: GlowButton(
                label: t('bk_restore_btn'),
                icon: Icons.upload_file_rounded,
                primary: false,
                onPressed: busy ? null : restore,
              ),
            ),
          ]),
        ),
        SectionTitle(t('bk_included')),
        GlassCard(child: Text(t('bk_included_list'), style: TextStyle(color: p.text, height: 1.6))),
      ]),
    );
  }
}

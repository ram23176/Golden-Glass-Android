// থিম: ৭টি তৈরি থিম + নিজের থিম, ডার্ক/লাইট মোড, থিম ফাইল import/export।

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/palette.dart';
import '../services/wallpaper_store.dart';
import '../ui/components.dart';
import 'shell.dart';
import 'theme_editor_page.dart';

class ThemesPage extends StatelessWidget {
  const ThemesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = app.palette;
    final top = MediaQuery.paddingOf(context).top;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, top + 14, 16, navBarSpace(context)),
      children: [
        Text(t('nav_themes'), style: TextStyle(color: p.text, fontSize: 26, fontWeight: FontWeight.w800)),
        Text(t('th_sub'), style: TextStyle(color: p.textMuted, fontSize: 13.5)),
        const SizedBox(height: 14),
        GlassCard(
          child: Row(children: [
            IconBadge(p.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, size: 40),
            const SizedBox(width: 12),
            Expanded(child: Text(t('th_mode'), style: TextStyle(color: p.text, fontWeight: FontWeight.w600))),
            ChoiceRow<bool>(
              options: const [true, false],
              value: app.dark,
              label: (d) => t(d ? 'mode_dark' : 'mode_light'),
              onChanged: app.setDark,
            ),
          ]),
        ),
        SectionTitle(t('th_deity')),
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 10),
          child: Text(t('th_deity_sub'), style: TextStyle(color: p.textMuted, fontSize: 12.5)),
        ),
        _ThemeGrid(themes: deityThemes),
        SectionTitle(t('th_builtin')),
        _ThemeGrid(themes: colorThemes),
        SectionTitle(
          t('th_custom'),
          trailing: TextButton.icon(
            onPressed: () => importTheme(context),
            icon: const Icon(Icons.file_open_rounded, size: 18),
            label: Text(t('th_import')),
          ),
        ),
        if (app.customThemes.isEmpty)
          GlassCard(
            child: Text(t('th_custom_empty'), style: TextStyle(color: p.textMuted)),
          )
        else
          _ThemeGrid(themes: app.customThemes),
        const SizedBox(height: 14),
        GlowButton(
          label: t('th_create'),
          icon: Icons.add_rounded,
          onPressed: () => openEditor(context, null),
        ),
        const SizedBox(height: 10),
        Text(t('th_hint'), textAlign: TextAlign.center, style: TextStyle(color: p.textMuted, fontSize: 12.5)),
      ],
    );
  }
}

void openEditor(BuildContext context, ThemeDef? theme) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => ThemeEditorPage(theme: theme)));
}

Future<void> importTheme(BuildContext context) async {
  final app = context.appRead;
  try {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null || !context.mounted) return;
    final size = await file.length() ?? 0;
    if (size > maxThemeImportBytes) throw const FormatException('th_err_file');
    final theme = parseThemeImport(await file.readAsBytes());
    final id = app.saveCustomTheme(theme);
    app.applyTheme(id);
    if (context.mounted) showToast(context, tf('th_imported', {'n': app.themeName(app.currentTheme)}));
  } on FormatException catch (e) {
    if (context.mounted) showToast(context, t(e.message), error: true);
  } catch (_) {
    if (context.mounted) showToast(context, t('th_err_file'), error: true);
  }
}

Future<void> exportTheme(BuildContext context, ThemeDef theme) async {
  final app = context.appRead;
  final name = app.themeName(theme);
  final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9_\-ঀ-৿]+'), '_');
  try {
    final uri = await FilePicker.saveFile(
      fileName: '$safe.ggtheme.json',
      bytes: utf8.encode(exportThemeJson(theme, name)),
      mimeType: 'application/json',
    );
    if (uri != null && context.mounted) showToast(context, t('th_exported'));
  } catch (_) {
    if (context.mounted) showToast(context, t('save_fail'), error: true);
  }
}

class _ThemeGrid extends StatelessWidget {
  const _ThemeGrid({required this.themes});

  final List<ThemeDef> themes;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemCount: themes.length,
      itemBuilder: (context, i) => _ThemeCard(theme: themes[i]),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.theme});

  final ThemeDef theme;

  void options(BuildContext context) {
    final app = context.appRead;
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.check_circle_outline_rounded),
              title: Text(t('th_apply')),
              onTap: () {
                Navigator.pop(c);
                app.applyTheme(theme.id);
              },
            ),
            ListTile(
              leading: Icon(theme.builtin ? Icons.copy_rounded : Icons.edit_rounded),
              title: Text(t(theme.builtin ? 'th_duplicate' : 'th_edit')),
              onTap: () {
                Navigator.pop(c);
                if (theme.builtin) {
                  final copy = ThemeDef(
                    id: '',
                    name: '${app.themeName(theme)} 2',
                    mode: theme.mode,
                    colors: Map.of(theme.colors),
                  );
                  openEditor(context, copy);
                } else {
                  openEditor(context, theme);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: Text(t('th_export')),
              onTap: () {
                Navigator.pop(c);
                exportTheme(context, theme);
              },
            ),
            if (!theme.builtin)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: Text(t('delete'), style: const TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(c);
                  if (await confirm(context, t('th_delete_title'), tf('th_delete_msg', {'n': theme.name}),
                      danger: true, ok: t('delete'))) {
                    app.deleteCustomTheme(theme.id);
                  }
                },
              ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = app.palette;
    final active = app.themeId == theme.id;
    final darkPreview = theme.forceMode ? theme.mode == 'dark' : app.dark;
    final tp = Palette.resolve(theme, darkPreview, app.look);
    final deityPics = theme.deity == null ? const <WallpaperItem>[] : app.inFolder(theme.deity!);
    return GlassCard(
      active: active,
      padding: const EdgeInsets.all(10),
      onTap: () {
        app.applyTheme(theme.id);
        if (theme.deity != null) {
          showToast(context, tf('th_deity_applied', {'f': app.themeName(theme), 'n': '${deityPics.length}'}));
        }
      },
      onLongPress: () => options(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: ThemeMiniPreview(palette: tp, imagePath: deityPics.firstOrNull?.path)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Text(app.themeName(theme),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.text, fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          if (active) Icon(Icons.check_circle_rounded, color: p.accent, size: 20),
          InkWell(
            onTap: () => options(context),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.more_vert_rounded, color: p.textMuted, size: 20),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// থিমের ছোট নমুনা: ব্যাকগ্রাউন্ড + কাচের কার্ড + accent বাটন
class ThemeMiniPreview extends StatelessWidget {
  const ThemeMiniPreview({super.key, required this.palette, this.imagePath});

  final Palette palette;

  /// দেবতার থিমে তাঁর ফোল্ডারের প্রথম ছবি পেছনে দেখায়
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final tp = palette;
    final r = context.look.radius * 0.6;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        image: imagePath == null
            ? null
            : DecorationImage(
                image: ResizeImage(FileImage(File(imagePath!)), width: 300),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(tp.background.withValues(alpha: 0.25), BlendMode.srcATop),
              ),
        gradient: imagePath != null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tp.bgGradA, tp.background, tp.bgGradC],
              ),
        border: Border.all(color: tp.border),
      ),
      padding: const EdgeInsets.all(8),
      child: imagePath != null
          // ছবি থাকলে ছবিটাই দেখা যাক — নিচে শুধু থিমের রঙের বাটন
          ? Align(
              alignment: Alignment.bottomRight,
              child: Container(
                width: 44,
                height: 14,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: LinearGradient(colors: [tp.buttonTop, tp.buttonBottom]),
                  boxShadow: [BoxShadow(color: tp.glow.withValues(alpha: 0.6), blurRadius: 8)],
                ),
              ),
            )
          : Container(
        decoration: BoxDecoration(
          color: tp.glassStrong,
          borderRadius: BorderRadius.circular(r * 0.8),
          border: Border.all(color: tp.border),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: tp.accent, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(color: tp.text.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Container(
            height: 5,
            width: 48,
            decoration: BoxDecoration(color: tp.textMuted.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(3)),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              width: 44,
              height: 14,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                gradient: LinearGradient(colors: [tp.buttonTop, tp.buttonBottom]),
                boxShadow: [BoxShadow(color: tp.glow.withValues(alpha: 0.5), blurRadius: 8)],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

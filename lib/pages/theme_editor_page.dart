// নিজের থিম তৈরি / সম্পাদনা: নাম, মোড, ৮টি রং, লাইভ প্রিভিউ।

import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/palette.dart';
import '../ui/color_picker.dart';
import '../ui/components.dart';
import 'themes_page.dart';

class ThemeEditorPage extends StatefulWidget {
  const ThemeEditorPage({super.key, this.theme});

  /// null = নতুন থিম; id খালি = কপি করা নতুন থিম
  final ThemeDef? theme;

  @override
  State<ThemeEditorPage> createState() => _ThemeEditorPageState();
}

class _ThemeEditorPageState extends State<ThemeEditorPage> {
  late ThemeDef draft;
  late TextEditingController name;
  bool dirty = false;

  bool get isExisting => widget.theme != null && widget.theme!.id.isNotEmpty;

  @override
  void initState() {
    super.initState();
    draft = widget.theme?.copy() ??
        ThemeDef(id: '', name: '', mode: 'dark', colors: colorsFromAccent('#FFB800', true));
    name = TextEditingController(text: draft.name);
    final original = draft.name;
    name.addListener(() {
      if (!dirty && name.text != original) setState(() => dirty = true);
    });
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void update(VoidCallback fn) => setState(() {
        fn();
        dirty = true;
      });

  Future<void> pick(String role) async {
    final picked = await showColorPicker(context, draft.colors[role]!, t('role_$role'));
    if (picked != null) update(() => draft.colors[role] = picked);
  }

  void save() {
    final app = context.appRead;
    draft.name = name.text.trim().isEmpty ? t('th_new_name') : name.text.trim();
    final id = app.saveCustomTheme(draft);
    app.applyTheme(id);
    dirty = false;
    showToast(context, t('th_saved'));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = app.palette;
    final preview = Palette.resolve(draft, draft.mode == 'dark', app.look);
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirm(context, t('th_discard_title'), t('th_discard_msg'), danger: true, ok: t('discard'))) {
          dirty = false;
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: GlassPage(
        title: t(isExisting ? 'th_edit' : 'th_create'),
        actions: [
          if (isExisting)
            IconButton(
              tooltip: t('th_export'),
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () {
                draft.name = name.text.trim().isEmpty ? draft.name : name.text.trim();
                exportTheme(context, draft);
              },
            ),
        ],
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          SizedBox(height: 150, child: ThemeMiniPreview(palette: preview)),
          const SizedBox(height: 16),
          TextField(
            controller: name,
            maxLength: 40,
            style: TextStyle(color: p.text),
            decoration: InputDecoration(labelText: t('th_name'), hintText: t('th_new_name')),
          ),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: Text(t('th_base_mode'), style: TextStyle(color: p.text, fontWeight: FontWeight.w600))),
            ChoiceRow<String>(
              options: const ['dark', 'light'],
              value: draft.mode,
              label: (m) => t('mode_$m'),
              onChanged: (m) => update(() {
                if (m == draft.mode) return;
                draft.colors = deriveVariant(draft.colors, m == 'dark');
                draft.mode = m;
              }),
            ),
          ]),
          SectionTitle(t('th_colors')),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              for (final role in themeRoles)
                ListTile(
                  onTap: () => pick(role),
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: hexColor(draft.colors[role]!),
                      shape: BoxShape.circle,
                      border: Border.all(color: p.borderHover, width: 1.5),
                    ),
                  ),
                  title: Text(t('role_$role'), style: TextStyle(color: p.text, fontWeight: FontWeight.w600)),
                  subtitle: Text(t('role_${role}_hint'), style: TextStyle(color: p.textMuted, fontSize: 12)),
                  trailing: Text(draft.colors[role]!, style: TextStyle(color: p.textMuted, fontFamily: 'monospace')),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          GlowButton(
            label: t('th_auto_colors'),
            icon: Icons.auto_fix_high_rounded,
            primary: false,
            onPressed: () => update(() => draft.colors = colorsFromAccent(draft.colors['accent']!, draft.mode == 'dark')),
          ),
          const SizedBox(height: 6),
          Text(t('th_auto_colors_hint'), style: TextStyle(color: p.textMuted, fontSize: 12)),
          const SizedBox(height: 16),
          GlowButton(label: t('save'), icon: Icons.check_rounded, onPressed: save),
        ]),
      ),
    );
  }
}

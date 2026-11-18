// ওয়ালপেপার: দেবতা অনুযায়ী ফোল্ডার, প্রিয়, নিজের ছবি যোগ/সরানো/মোছা,
// Home/Lock screen-এ সেট, স্বয়ংক্রিয় বদল।

import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/i18n.dart';
import '../core/palette.dart';
import '../services/wallpaper_store.dart';
import '../ui/components.dart';
import 'shell.dart';

/// ফোল্ডারের চিহ্নের রং: দেবতার থিমের accent, "অন্যান্য" হলে ধূসর
Color folderColor(String folder) {
  final th = deityThemes.where((x) => x.deity == folder).firstOrNull;
  return th == null ? const Color(0xFF94A3B8) : hexColor(th.colors['accent']!);
}

/// কোন ফোল্ডারে রাখবেন — বাছাইয়ের তালিকা
Future<String?> pickFolder(BuildContext context, {String? current, required String title}) {
  final app = context.appRead;
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(title, style: TextStyle(color: app.palette.text, fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          for (final f in allFolders)
            ListTile(
              leading: CircleAvatar(radius: 14, backgroundColor: folderColor(f)),
              title: Text(t('deity_$f')),
              subtitle: Text(tf('wp_count', {'n': '${app.inFolder(f).length}'})),
              trailing: f == current ? Icon(Icons.check_rounded, color: app.palette.accent) : null,
              onTap: () => Navigator.pop(c, f),
            ),
        ]),
      ),
    ),
  );
}

class WallpaperPage extends StatefulWidget {
  const WallpaperPage({super.key});

  @override
  State<WallpaperPage> createState() => _WallpaperPageState();
}

class _WallpaperPageState extends State<WallpaperPage> {
  bool adding = false;
  bool nextBusy = false;
  final Set<String> selected = {}; // লম্বা চাপে বাছাই করা ছবির path

  bool get selecting => selected.isNotEmpty;

  Future<void> addPhotos() async {
    final app = context.appRead;
    var folder = allFolders.contains(app.wallpaperFilter) ? app.wallpaperFilter : null;
    folder ??= await pickFolder(context, title: t('wp_add_where'));
    if (folder == null || !mounted) return;
    setState(() => adding = true);
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty || !mounted) return;
      final added = await app.addWallpapers(files, folder);
      if (!mounted) return;
      if (added > 0) app.setWallpaperFilter(folder); // যোগ করা ছবিগুলো সাথে সাথে দেখানো
      showToast(
        context,
        added > 0 ? tf('wp_added_to', {'n': '$added', 'f': t('deity_$folder')}) : t('wp_add_none'),
        error: added == 0,
      );
    } catch (e) {
      if (mounted) showToast(context, t('wp_add_fail'), error: true);
    } finally {
      if (mounted) setState(() => adding = false);
    }
  }

  Future<void> next() async {
    setState(() => nextBusy = true);
    final ok = await context.appRead.nextWallpaper();
    if (!mounted) return;
    setState(() => nextBusy = false);
    showToast(context, ok ? t('wp_set_ok') : t('wp_set_fail'), error: !ok);
  }

  void toggleSelect(WallpaperItem item) {
    if (item.bundled) {
      showToast(context, t('wp_builtin_no_delete'), error: true);
      return;
    }
    setState(() {
      if (!selected.remove(item.path)) selected.add(item.path);
    });
  }

  Future<void> deleteItems(List<WallpaperItem> items) async {
    final app = context.appRead;
    if (items.isEmpty) return;
    final msg = items.length == 1 ? t('wp_delete_msg') : tf('wp_delete_many_msg', {'n': '${items.length}'});
    if (!await confirm(context, t('wp_delete_title'), msg, danger: true, ok: t('delete'))) return;
    final n = await app.deleteWallpapers(items);
    if (!mounted) return;
    setState(selected.clear);
    showToast(context, tf('wp_deleted', {'n': '$n'}));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = app.palette;
    final top = MediaQuery.paddingOf(context).top;
    final items = app.filteredWallpapers;
    selected.removeWhere((path) => !app.wallpapers.any((w) => w.path == path));

    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(selected.clear);
      },
      child: CustomScrollView(slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, top + 14, 16, 0),
          sliver: SliverList.list(children: [
            if (selecting)
              _SelectionBar(
                count: selected.length,
                onCancel: () => setState(selected.clear),
                onDelete: () => deleteItems(app.wallpapers.where((w) => selected.contains(w.path)).toList()),
              )
            else
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t('nav_wallpapers'), style: TextStyle(color: p.text, fontSize: 26, fontWeight: FontWeight.w800)),
                    Text(tf('wp_count', {'n': '${app.wallpapers.length}'}),
                        style: TextStyle(color: p.textMuted, fontSize: 13.5)),
                  ]),
                ),
                GlowButton(label: t('wp_add'), icon: Icons.add_photo_alternate_rounded, busy: adding, onPressed: addPhotos),
              ]),
            const SizedBox(height: 14),
            _AutoChangerCard(nextBusy: nextBusy, onNext: next),
            const SizedBox(height: 16),
            // ---- ফোল্ডার / ফিল্টার ----
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ChoiceRow<String>(
                options: wallpaperFilters,
                value: app.wallpaperFilter,
                label: (o) => switch (o) {
                  'all' => '${t('wp_filter_all')} ${app.wallpapers.length}',
                  'fav' => '${t('wp_filter_fav')} ${app.wallpapers.where((w) => app.favorites.contains(w.id)).length}',
                  _ => '${t('deity_$o')} ${app.inFolder(o).length}',
                },
                onChanged: app.setWallpaperFilter,
              ),
            ),
            const SizedBox(height: 8),
            Text(t(selecting ? 'wp_select_hint' : 'wp_longpress_hint'),
                style: TextStyle(color: p.textMuted, fontSize: 12)),
            const SizedBox(height: 10),
            if (items.isEmpty) _EmptyFolder(filter: app.wallpaperFilter, onAdd: addPhotos),
          ]),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, navBarSpace(context)),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.62,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return _WallpaperTile(
                item: item,
                selecting: selecting,
                selected: selected.contains(item.path),
                onTap: () => selecting ? toggleSelect(item) : showWallpaperSheet(context, item),
                onLongPress: () => toggleSelect(item),
                onDelete: () => deleteItems([item]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.count, required this.onCancel, required this.onDelete});

  final int count;
  final VoidCallback onCancel, onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return GlassCard(
      active: true,
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      child: Row(children: [
        IconButton(tooltip: t('cancel'), onPressed: onCancel, icon: Icon(Icons.close_rounded, color: p.text)),
        Expanded(
          child: Text(tf('wp_selected', {'n': '$count'}),
              style: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        GlowButton(label: t('delete'), icon: Icons.delete_rounded, danger: true, compact: true, onPressed: onDelete),
      ]),
    );
  }
}

class _EmptyFolder extends StatelessWidget {
  const _EmptyFolder({required this.filter, required this.onAdd});

  final String filter;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final isFolder = allFolders.contains(filter);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(children: [
        Icon(filter == 'fav' ? Icons.star_border_rounded : Icons.photo_library_outlined, size: 48, color: p.textMuted),
        const SizedBox(height: 10),
        Text(
          filter == 'fav' ? t('wp_empty_fav') : tf('wp_empty_folder', {'f': isFolder ? t('deity_$filter') : ''}),
          textAlign: TextAlign.center,
          style: TextStyle(color: p.textMuted),
        ),
        if (isFolder) ...[
          const SizedBox(height: 14),
          GlowButton(label: t('wp_add'), icon: Icons.add_photo_alternate_rounded, compact: true, onPressed: onAdd),
        ],
      ]),
    );
  }
}

class _AutoChangerCard extends StatelessWidget {
  const _AutoChangerCard({required this.nextBusy, required this.onNext});

  final bool nextBusy;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = app.palette;
    final pool = app.autoPool.length;
    final deity = app.activeDeity;
    return GlassCard(
      active: app.autoEnabled,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SwitchRow(
          icon: Icons.autorenew_rounded,
          title: t('auto_title'),
          subtitle: app.autoEnabled ? tf('home_auto_on', {'t': formatInterval(app.autoMinutes)}) : t('auto_sub'),
          value: app.autoEnabled,
          onChanged: (v) {
            if (v && pool == 0) {
              showToast(context, t('auto_need_pool'), error: true);
              return;
            }
            app.setAuto(enabled: v);
          },
        ),
        AnimatedSize(
          duration: app.look.anim(250),
          curve: Curves.easeOutCubic,
          child: !app.autoEnabled
              ? const SizedBox(width: double.infinity)
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Divider(color: p.divider, height: 20),
                  Text(t('auto_interval'), style: TextStyle(color: p.textMuted, fontSize: 13)),
                  const SizedBox(height: 8),
                  ChoiceRow<int>(
                    options: autoIntervals,
                    value: app.autoMinutes,
                    label: formatInterval,
                    onChanged: (m) => app.setAuto(minutes: m),
                  ),
                  const SizedBox(height: 14),
                  Text(t('wp_where'), style: TextStyle(color: p.textMuted, fontSize: 13)),
                  const SizedBox(height: 8),
                  ChoiceRow<String>(
                    options: wallpaperTargets,
                    value: app.autoTarget,
                    label: (o) => t('target_$o'),
                    onChanged: (o) => app.setAuto(target: o),
                  ),
                  const SizedBox(height: 6),
                  if (deity != null)
                    SwitchRow(
                      title: tf('auto_deity_only', {'f': t('deity_$deity')}),
                      value: app.autoDeityOnly,
                      onChanged: (v) => app.setAuto(deityOnly: v),
                    ),
                  SwitchRow(
                    title: t('auto_shuffle'),
                    value: app.autoShuffle,
                    onChanged: (v) => app.setAuto(shuffle: v),
                  ),
                  SwitchRow(
                    title: t('auto_fav_only'),
                    value: app.autoFavoritesOnly,
                    onChanged: (v) => app.setAuto(favoritesOnly: v),
                  ),
                  Text(tf('auto_pool', {'n': '$pool'}),
                      style: TextStyle(color: pool == 0 ? Colors.redAccent : p.accentText, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(t('auto_note'), style: TextStyle(color: p.textMuted, fontSize: 12)),
                ]),
        ),
        if (pool > 0) ...[
          const SizedBox(height: 12),
          GlowButton(
            label: t('wp_next'),
            icon: Icons.skip_next_rounded,
            compact: true,
            primary: false,
            busy: nextBusy,
            onPressed: onNext,
          ),
        ],
      ]),
    );
  }
}

class _WallpaperTile extends StatelessWidget {
  const _WallpaperTile({
    required this.item,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
  });

  final WallpaperItem item;
  final bool selecting, selected;
  final VoidCallback onTap, onLongPress, onDelete;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = app.palette;
    final r = BorderRadius.circular(app.look.radius);
    final isCurrent = app.currentWallpaper == item.path;
    final fav = app.favorites.contains(item.id);
    final highlight = selected || (isCurrent && !selecting);
    return AnimatedContainer(
      duration: app.look.anim(220),
      decoration: BoxDecoration(
        borderRadius: r,
        border: Border.all(
          color: selected ? Colors.redAccent : (isCurrent ? p.accent : p.border),
          width: highlight ? 2.5 : 1,
        ),
        boxShadow: highlight && app.look.glow > 0
            ? [
                BoxShadow(
                  color: (selected ? Colors.redAccent : p.glow).withValues(alpha: 0.4 * app.look.glow),
                  blurRadius: 16 * app.look.glow,
                )
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Material(
          color: p.glassInput,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Stack(fit: StackFit.expand, children: [
              Image.file(
                File(item.path),
                fit: BoxFit.cover,
                cacheWidth: 360,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => Icon(Icons.broken_image_outlined, color: p.textMuted),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? Colors.black.withValues(alpha: 0.35) : null,
                  gradient: selected
                      ? null
                      : const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.transparent, Color(0xB0000000)],
                          stops: [0, 0.55, 1],
                        ),
                ),
              ),
              Positioned(
                left: 10,
                right: item.bundled || selecting ? 10 : 48,
                bottom: 10,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    wallpaperName(item.id, item.bundled),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: folderColor(item.folder), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(t('deity_${item.folder}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                    ),
                  ]),
                ]),
              ),
              if (isCurrent && !selecting)
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(colors: [p.buttonTop, p.buttonBottom]),
                    ),
                    child: Text(t('wp_current'),
                        style: TextStyle(color: p.onAccent, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
              if (selecting)
                Positioned(
                  left: 8,
                  top: 8,
                  child: Icon(
                    item.bundled
                        ? Icons.lock_rounded
                        : (selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded),
                    color: selected ? Colors.redAccent : Colors.white,
                    size: 28,
                  ),
                )
              else ...[
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton(
                    tooltip: t(fav ? 'wp_unfav' : 'wp_fav'),
                    onPressed: () => app.toggleFavorite(item),
                    icon: Icon(fav ? Icons.star_rounded : Icons.star_border_rounded,
                        color: fav ? p.accent : Colors.white, size: 26),
                    style: IconButton.styleFrom(backgroundColor: const Color(0x55000000)),
                  ),
                ),
                // নিজের যোগ করা ছবিতে সরাসরি মোছার বাটন
                if (!item.bundled)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: IconButton(
                      tooltip: t('delete'),
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
                      style: IconButton.styleFrom(backgroundColor: const Color(0x66B00020)),
                    ),
                  ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// ফোনের স্ক্রিনে ওয়ালপেপার কেমন দেখাবে (native WallpaperHelper-এর মতো একই নিয়মে)
class _PhonePreview extends StatefulWidget {
  const _PhonePreview({required this.path, required this.fit});

  final String path;
  final String fit;

  @override
  State<_PhonePreview> createState() => _PhonePreviewState();
}

class _PhonePreviewState extends State<_PhonePreview> {
  late final ImageProvider image = ResizeImage(FileImage(File(widget.path)), width: 720);
  bool? landscape;
  ImageStream? stream;
  late final ImageStreamListener listener = ImageStreamListener((info, _) {
    if (mounted) setState(() => landscape = info.image.width > info.image.height);
  });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    stream?.removeListener(listener);
    stream = image.resolve(createLocalImageConfiguration(context))..addListener(listener);
  }

  @override
  void dispose() {
    stream?.removeListener(listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final useFit = widget.fit == 'fit' || (widget.fit == 'auto' && (landscape ?? false));
    if (!useFit) return Image(image: image, fit: BoxFit.cover, gaplessPlayback: true);
    return Stack(fit: StackFit.expand, children: [
      ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18, tileMode: TileMode.clamp),
        child: Image(image: image, fit: BoxFit.cover, gaplessPlayback: true),
      ),
      const ColoredBox(color: Color(0x59000000)),
      Image(image: image, fit: BoxFit.contain, gaplessPlayback: true),
    ]);
  }
}

/// ছবিতে চাপ দিলে: বড় প্রিভিউ + কোথায় সেট করবেন + প্রিয় + ফোল্ডার বদল + মুছুন
Future<void> showWallpaperSheet(BuildContext context, WallpaperItem item) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _WallpaperSheet(item: item),
  );
}

class _WallpaperSheet extends StatefulWidget {
  const _WallpaperSheet({required this.item});

  final WallpaperItem item;

  @override
  State<_WallpaperSheet> createState() => _WallpaperSheetState();
}

class _WallpaperSheetState extends State<_WallpaperSheet> {
  String? busyTarget;

  Future<void> apply(String target) async {
    setState(() => busyTarget = target);
    final ok = await context.appRead.setWallpaper(widget.item, target);
    if (!mounted) return;
    setState(() => busyTarget = null);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(ok ? t('wp_set_ok') : t('wp_set_fail'))));
  }

  Future<void> delete() async {
    final app = context.appRead;
    if (!await confirm(context, t('wp_delete_title'), t('wp_delete_msg'), danger: true, ok: t('delete'))) return;
    await app.deleteWallpapers([widget.item]);
    if (mounted) Navigator.pop(context);
  }

  Future<void> move() async {
    final app = context.appRead;
    final folder = await pickFolder(context, current: widget.item.folder, title: t('wp_move_to'));
    if (folder == null || folder == widget.item.folder || !mounted) return;
    await app.moveWallpaper(widget.item, folder);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(tf('wp_moved', {'f': t('deity_$folder')}))));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = app.palette;
    final item = widget.item;
    final fav = app.favorites.contains(item.id);
    final h = MediaQuery.sizeOf(context).height;
    final busy = busyTarget != null;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.paddingOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: p.track, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(app.look.radius),
          child: SizedBox(
            height: h * 0.40,
            child: AspectRatio(
              aspectRatio: MediaQuery.sizeOf(context).aspectRatio.clamp(0.4, 0.8),
              child: _PhonePreview(path: item.path, fit: app.wallpaperFit),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Text(t('fit_label'), style: TextStyle(color: p.textMuted, fontSize: 13)),
          const SizedBox(width: 10),
          Expanded(
            child: ChoiceRow<String>(
              options: wallpaperFits,
              value: app.wallpaperFit,
              label: (f) => t('fit_$f'),
              onChanged: app.setFit,
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(wallpaperName(item.id, item.bundled),
                  style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w700)),
              Row(children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: folderColor(item.folder), shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(t('deity_${item.folder}'), style: TextStyle(color: p.textMuted, fontSize: 13)),
              ]),
            ]),
          ),
          IconButton(
            tooltip: t(fav ? 'wp_unfav' : 'wp_fav'),
            onPressed: () => app.toggleFavorite(item),
            icon: Icon(fav ? Icons.star_rounded : Icons.star_border_rounded, color: p.accent, size: 28),
          ),
        ]),
        if (!item.bundled) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: GlowButton(
                label: t('wp_move'),
                icon: Icons.drive_file_move_rounded,
                primary: false,
                compact: true,
                onPressed: busy ? null : move,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GlowButton(
                label: t('delete'),
                icon: Icons.delete_outline_rounded,
                primary: false,
                danger: true,
                compact: true,
                onPressed: busy ? null : delete,
              ),
            ),
          ]),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(t('wp_where'), style: TextStyle(color: p.textMuted, fontSize: 13)),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: GlowButton(
              label: t('target_home'),
              icon: Icons.home_rounded,
              primary: false,
              compact: true,
              busy: busyTarget == 'home',
              onPressed: busy ? null : () => apply('home'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GlowButton(
              label: t('target_lock'),
              icon: Icons.lock_rounded,
              primary: false,
              compact: true,
              busy: busyTarget == 'lock',
              onPressed: busy ? null : () => apply('lock'),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: GlowButton(
            label: t('target_both'),
            icon: Icons.check_circle_rounded,
            busy: busyTarget == 'both',
            onPressed: busy ? null : () => apply('both'),
          ),
        ),
      ]),
    );
  }
}

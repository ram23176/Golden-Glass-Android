// অ্যাপের সব সেটিংস ও অবস্থা এক জায়গায়। কিছু বদলালে notifyListeners() → UI আবার আঁকা হয়,
// আর সেটিংস ফোনে সংরক্ষিত হয় (SharedPreferences, JSON আকারে)।

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/native.dart';
import '../services/wallpaper_store.dart';
import 'app_info.dart';
import 'i18n.dart';
import 'palette.dart';

const autoIntervals = [15, 30, 60, 180, 360, 720, 1440]; // মিনিট
const wallpaperTargets = ['home', 'lock', 'both'];
const wallpaperFits = ['auto', 'fill', 'fit'];
const backupFormat = 'golden-glass-android-backup';

/// ওয়ালপেপার পেজের ফিল্টার: সব, প্রিয়, অথবা কোনো একটি ফোল্ডার
const wallpaperFilters = ['all', 'fav', ...allFolders];

class AppState extends ChangeNotifier {
  AppState({SharedPreferences? prefs, WallpaperStore? store})
      : store = store ?? WallpaperStore() {
    _prefs = prefs;
  }

  static const _key = 'gg_state_v1';

  SharedPreferences? _prefs;
  final WallpaperStore store;

  // ---- সেটিংস ----
  String lang = 'bn';
  String themeId = 'golden_glass';
  bool dark = true;
  Appearance look = const Appearance();
  List<ThemeDef> customThemes = [];
  Set<String> favorites = {};
  String wallpaperFilter = 'all';
  bool autoEnabled = false;
  int autoMinutes = 60;
  bool autoShuffle = false;
  bool autoFavoritesOnly = false;
  bool autoDeityOnly = true; // দেবতার থিম চালু থাকলে শুধু তাঁর ফোল্ডার থেকে বদল
  String autoTarget = 'both';
  String wallpaperFit = 'auto'; // auto | fill (স্ক্রিন ভরানো) | fit (পুরো ছবি)
  double storageWarn = 20; // % খালি থাকলে হলুদ
  double storageCritical = 10; // % খালি থাকলে লাল

  // ---- চলমান অবস্থা (সংরক্ষিত নয়) ----
  List<WallpaperItem> wallpapers = [];
  String? currentWallpaper;
  bool ready = false;

  // ================= শুরু =================

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw != null) {
      try {
        applySettings(jsonDecode(raw));
      } catch (e) {
        debugPrint('settings corrupt, using defaults: $e');
      }
    }
    I18n.lang = lang;
    try {
      await store.init();
      wallpapers = await store.list();
    } catch (e) {
      debugPrint('wallpaper store init failed: $e');
    }
    currentWallpaper = _matchPath(await Native.lastWallpaper());
    ready = true;
    notifyListeners();
    await syncNative();
  }

  /// ছবি অন্য ফোল্ডারে সরে গেলে (যেমন 1.0.0 থেকে আপডেটের পর) ফাইলের নাম মিলিয়ে নতুন পাথ খোঁজে
  String? _matchPath(String? path) {
    if (path == null || wallpapers.any((w) => w.path == path)) return path;
    final name = path.split(RegExp(r'[\\/]')).last;
    return wallpapers.where((w) => w.id == name).firstOrNull?.path ?? path;
  }

  /// Native অংশকে (উইজেট + অটো-চেঞ্জার) বর্তমান সেটিংস জানায়।
  Future<void> syncNative() async {
    await Native.configurePool(autoPool.map((w) => w.path).toList(), autoShuffle, autoTarget, wallpaperFit);
    final accent = hexColor(currentTheme.colors['accent']!).toARGB32();
    await Native.configureWidget(accent: accent.toSigned(32), free: t('w_free'), next: t('w_next'));
  }

  Future<void> refreshCurrentWallpaper() async {
    final last = _matchPath(await Native.lastWallpaper());
    if (last != currentWallpaper) {
      currentWallpaper = last;
      notifyListeners();
    }
  }

  // ================= থিম =================

  List<ThemeDef> get allThemes => [...builtinThemes, ...customThemes];

  ThemeDef get currentTheme =>
      allThemes.firstWhere((th) => th.id == themeId, orElse: () => colorThemes.first);

  /// দেবতার থিম চালু থাকলে সেই দেবতার ফোল্ডার, নইলে null
  String? get activeDeity => currentTheme.deity;

  Palette? _palette;
  Palette get palette => _palette ??= Palette.resolve(currentTheme, dark, look);

  @override
  void notifyListeners() {
    _palette = null; // থিম/মোড/Appearance বদলে থাকতে পারে
    super.notifyListeners();
  }

  String themeName(ThemeDef th) {
    if (th.deity != null) return t('deity_${th.deity}');
    return th.builtin ? t('theme_${th.id}') : th.name;
  }

  void applyTheme(String id) {
    final th = allThemes.where((x) => x.id == id).firstOrNull;
    if (th == null) return;
    themeId = id;
    if (th.forceMode) dark = th.mode == 'dark';
    if (th.deity != null) wallpaperFilter = th.deity!; // দেবতার ছবিগুলো সামনে আনা
    _changed(native: true);
  }

  void setDark(bool value) {
    dark = value;
    _changed();
  }

  String uniqueThemeName(String name, {String? exceptId}) {
    final names = {
      for (final th in allThemes)
        if (th.id != exceptId) themeName(th)
    };
    if (!names.contains(name)) return name;
    var i = 2;
    while (names.contains('$name ($i)')) {
      i++;
    }
    return '$name ($i)';
  }

  /// নতুন বা পুরনো কাস্টম থিম সংরক্ষণ; id ফেরত দেয়।
  String saveCustomTheme(ThemeDef theme) {
    final id = theme.id.isNotEmpty ? theme.id : 'custom_${DateTime.now().microsecondsSinceEpoch}';
    final saved = ThemeDef(
      id: id,
      name: uniqueThemeName(cleanName(theme.name, 'Custom'), exceptId: id),
      mode: theme.mode == 'light' ? 'light' : 'dark',
      colors: sanitizeColors(theme.colors) ?? Map.of(goldenColors),
    );
    final i = customThemes.indexWhere((x) => x.id == id);
    if (i >= 0) {
      customThemes[i] = saved;
    } else {
      customThemes.add(saved);
    }
    _changed(native: id == themeId);
    return id;
  }

  void deleteCustomTheme(String id) {
    customThemes.removeWhere((x) => x.id == id);
    if (themeId == id) themeId = 'golden_glass';
    _changed(native: true);
  }

  // ================= Appearance / ভাষা =================

  void setLook(Appearance value) {
    look = value;
    _changed();
  }

  void setLang(String value) {
    lang = value == 'en' ? 'en' : 'bn';
    I18n.lang = lang;
    _changed(native: true);
  }

  void setStorageBands(double warn, double critical) {
    storageWarn = warn.clamp(5, 50);
    storageCritical = critical.clamp(1, storageWarn - 1);
    _changed();
  }

  // ================= ওয়ালপেপার =================

  WallpaperItem? get currentItem => wallpapers.where((w) => w.path == currentWallpaper).firstOrNull;

  List<WallpaperItem> inFolder(String folder) => wallpapers.where((w) => w.folder == folder).toList();

  /// ওয়ালপেপার পেজে এখন যে ছবিগুলো দেখাবে
  List<WallpaperItem> get filteredWallpapers => switch (wallpaperFilter) {
        'all' => wallpapers,
        'fav' => wallpapers.where((w) => favorites.contains(w.id)).toList(),
        final folder => inFolder(folder),
      };

  void setWallpaperFilter(String value) {
    if (!wallpaperFilters.contains(value)) return;
    wallpaperFilter = value;
    _changed();
  }

  /// অ্যাপের নিজের ব্যাকগ্রাউন্ডে যে ছবি দেখায়
  String? get backgroundPath {
    if (!look.wallpaperBackground) return null;
    final deity = activeDeity;
    if (deity != null) {
      final own = inFolder(deity);
      if (own.isNotEmpty) {
        return own.any((w) => w.path == currentWallpaper) ? currentWallpaper : own.first.path;
      }
    }
    if (currentItem != null) return currentItem!.path;
    return wallpapers.isEmpty ? null : wallpapers.first.path;
  }

  /// স্বয়ংক্রিয় বদল / ⏭ বাটন যে ছবিগুলো থেকে বেছে নেয়
  List<WallpaperItem> get autoPool {
    final deity = activeDeity;
    var pool = deity != null && autoDeityOnly ? inFolder(deity) : wallpapers;
    if (autoFavoritesOnly) pool = pool.where((w) => favorites.contains(w.id)).toList();
    return pool;
  }

  void toggleFavorite(WallpaperItem item) {
    if (!favorites.remove(item.id)) favorites.add(item.id);
    _changed(native: true);
  }

  Future<int> addWallpapers(List<dynamic> picked, String folder) async {
    final added = await store.importPicked(picked.cast(), folder);
    if (added > 0) await reloadWallpapers();
    return added;
  }

  Future<void> moveWallpaper(WallpaperItem item, String folder) async {
    final newPath = await store.move(item, folder);
    if (newPath == null) return;
    if (currentWallpaper == item.path) currentWallpaper = newPath;
    await reloadWallpapers();
  }

  /// এক বা একাধিক নিজের ছবি মোছে; কয়টি মুছল তা ফেরত দেয় (অ্যাপের ছবি মোছা যায় না)।
  Future<int> deleteWallpapers(Iterable<WallpaperItem> items) async {
    var deleted = 0;
    for (final item in items) {
      if (await store.delete(item)) {
        favorites.remove(item.id);
        deleted++;
      }
    }
    if (deleted > 0) {
      await reloadWallpapers();
      _changed(native: true);
    }
    return deleted;
  }

  Future<void> reloadWallpapers() async {
    wallpapers = await store.list();
    favorites.removeWhere((id) => !wallpapers.any((w) => w.id == id));
    notifyListeners();
    await syncNative();
  }

  void setFit(String value) {
    if (!wallpaperFits.contains(value)) return;
    wallpaperFit = value;
    _changed(native: true);
  }

  Future<bool> setWallpaper(WallpaperItem item, String target) async {
    final ok = await Native.setWallpaper(item.path, target, wallpaperFit);
    if (ok) {
      currentWallpaper = item.path;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> nextWallpaper() async {
    final path = await Native.nextWallpaper();
    if (path == null) return false;
    currentWallpaper = path;
    notifyListeners();
    return true;
  }

  Future<void> setAuto({
    bool? enabled,
    int? minutes,
    bool? shuffle,
    bool? favoritesOnly,
    bool? deityOnly,
    String? target,
  }) async {
    final reschedule = (enabled != null && enabled != autoEnabled) || (minutes != null && minutes != autoMinutes);
    autoEnabled = enabled ?? autoEnabled;
    if (minutes != null && autoIntervals.contains(minutes)) autoMinutes = minutes;
    autoShuffle = shuffle ?? autoShuffle;
    autoFavoritesOnly = favoritesOnly ?? autoFavoritesOnly;
    autoDeityOnly = deityOnly ?? autoDeityOnly;
    if (target != null && wallpaperTargets.contains(target)) autoTarget = target;
    _changed(native: true);
    if (reschedule) await _applySchedule();
  }

  Future<void> _applySchedule() async {
    if (autoEnabled) {
      await Native.scheduleAuto(autoMinutes);
    } else {
      await Native.cancelAuto();
    }
  }

  // ================= সংরক্ষণ =================

  Map<String, dynamic> settingsJson() => {
        'lang': lang,
        'themeId': themeId,
        'dark': dark,
        'appearance': look.toJson(),
        'customThemes': [for (final th in customThemes) th.toJson()],
        'favorites': favorites.toList()..sort(),
        'wallpaperFilter': wallpaperFilter,
        'auto': {
          'enabled': autoEnabled,
          'minutes': autoMinutes,
          'shuffle': autoShuffle,
          'favoritesOnly': autoFavoritesOnly,
          'deityOnly': autoDeityOnly,
          'target': autoTarget,
        },
        'wallpaperFit': wallpaperFit,
        'storage': {'warn': storageWarn, 'critical': storageCritical},
      };

  /// JSON থেকে সেটিংস নেয় — অচেনা/ভুল মান উপেক্ষা করে ডিফল্ট রাখে।
  void applySettings(Object? raw) {
    if (raw is! Map) return;
    if (raw['lang'] == 'en' || raw['lang'] == 'bn') lang = raw['lang'] as String;
    if (raw['dark'] is bool) dark = raw['dark'] as bool;
    look = Appearance.fromJson(raw['appearance']);
    final themes = raw['customThemes'];
    if (themes is List) {
      final seen = <String>{};
      customThemes = [
        for (final e in themes.take(100))
          if (ThemeDef.fromJson(e) case final th? when seen.add(th.id)) th
      ];
    }
    final id = raw['themeId'];
    themeId = id is String && allThemes.any((th) => th.id == id) ? id : 'golden_glass';
    final fav = raw['favorites'];
    if (fav is List) favorites = {for (final f in fav) if (f is String) f};
    if (wallpaperFilters.contains(raw['wallpaperFilter'])) wallpaperFilter = raw['wallpaperFilter'] as String;
    final auto = raw['auto'];
    if (auto is Map) {
      if (auto['enabled'] is bool) autoEnabled = auto['enabled'] as bool;
      if (autoIntervals.contains(auto['minutes'])) autoMinutes = auto['minutes'] as int;
      if (auto['shuffle'] is bool) autoShuffle = auto['shuffle'] as bool;
      if (auto['favoritesOnly'] is bool) autoFavoritesOnly = auto['favoritesOnly'] as bool;
      if (auto['deityOnly'] is bool) autoDeityOnly = auto['deityOnly'] as bool;
      if (wallpaperTargets.contains(auto['target'])) autoTarget = auto['target'] as String;
    }
    if (wallpaperFits.contains(raw['wallpaperFit'])) wallpaperFit = raw['wallpaperFit'] as String;
    final st = raw['storage'];
    if (st is Map && st['warn'] is num && st['critical'] is num) {
      storageWarn = (st['warn'] as num).toDouble().clamp(5, 50);
      storageCritical = (st['critical'] as num).toDouble().clamp(1, storageWarn - 1);
    }
  }

  void _changed({bool native = false}) {
    notifyListeners();
    _prefs?.setString(_key, jsonEncode(settingsJson()));
    if (native) syncNative();
  }

  // ================= ব্যাকআপ =================

  String exportBackup() => const JsonEncoder.withIndent('  ').convert({
        'format': backupFormat,
        'version': 1,
        'app': appName,
        'appVersion': appVersion,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'settings': settingsJson(),
      });

  /// ব্যাকআপ যাচাই করে প্রয়োগ করে। সমস্যা হলে FormatException(i18n key)।
  Future<void> importBackup(List<int> bytes) async {
    if (bytes.isEmpty || bytes.length > 2 * 1024 * 1024) throw const FormatException('bk_err_file');
    Object? data;
    try {
      var text = utf8.decode(bytes);
      if (text.startsWith('﻿')) text = text.substring(1);
      data = jsonDecode(text);
    } catch (_) {
      throw const FormatException('bk_err_file');
    }
    if (data is! Map || data['format'] != backupFormat || data['settings'] is! Map) {
      throw const FormatException('bk_err_format');
    }
    if (data['version'] is! int || (data['version'] as int) > 1) throw const FormatException('bk_err_version');
    resetToDefaults(save: false);
    applySettings(data['settings']);
    favorites.removeWhere((id) => !wallpapers.any((w) => w.id == id));
    I18n.lang = lang;
    _changed(native: true);
    await _applySchedule();
  }

  /// ভাষা ছাড়া সব সেটিংস প্রথম অবস্থায় ফেরায় (ছবি মোছে না)।
  void resetToDefaults({bool save = true}) {
    themeId = 'golden_glass';
    dark = true;
    look = const Appearance();
    customThemes = [];
    favorites = {};
    wallpaperFilter = 'all';
    autoEnabled = false;
    autoMinutes = 60;
    autoShuffle = false;
    autoFavoritesOnly = false;
    autoDeityOnly = true;
    autoTarget = 'both';
    wallpaperFit = 'auto';
    storageWarn = 20;
    storageCritical = 10;
    if (save) {
      _changed(native: true);
      _applySchedule();
    }
  }
}

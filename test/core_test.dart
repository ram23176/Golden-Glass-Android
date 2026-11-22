import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_glass/core/app_info.dart';
import 'package:golden_glass/core/app_state.dart';
import 'package:golden_glass/core/i18n.dart';
import 'package:golden_glass/core/palette.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('i18n', () {
    test('bn and en have exactly the same keys', () {
      final bn = strings['bn']!.keys.toSet();
      final en = strings['en']!.keys.toSet();
      expect(bn.difference(en), isEmpty, reason: 'missing in en');
      expect(en.difference(bn), isEmpty, reason: 'missing in bn');
    });

    test('every literal key used in lib/ exists', () {
      final used = <String>{};
      final re = RegExp(r"\btf?\('([a-z0-9_]+)'");
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        for (final m in re.allMatches(f.readAsStringSync())) {
          used.add(m.group(1)!);
        }
      }
      // যেসব key কোডে জোড়া লাগিয়ে তৈরি হয়
      for (final r in themeRoles) {
        used..add('role_$r')..add('role_${r}_hint');
      }
      for (final th in builtinThemes) {
        // দেবতার থিমের নাম আসে deity_<ফোল্ডার> থেকে
        used.add(th.deity != null ? 'deity_${th.deity}' : 'theme_${th.id}');
      }
      for (final x in ['all', 'fav']) {
        used.add('wp_filter_$x');
      }
      for (final f in allFolders) {
        used.add('deity_$f');
      }
      for (final x in [...wallpaperTargets.map((e) => 'target_$e'), ...wallpaperFits.map((e) => 'fit_$e')]) {
        used.add(x);
      }
      for (final x in ['ac', 'usb', 'wireless', 'none', 'other']) {
        used.add('plug_$x');
      }
      for (final x in ['good', 'overheat', 'dead', 'over_voltage', 'cold', 'unknown']) {
        used.add('health_$x');
      }
      for (var i = 1; i <= 7; i++) {
        used.add('wd_$i');
      }
      for (var i = 1; i <= 12; i++) {
        used.add('mo_$i');
      }
      used.addAll(['th_err_file', 'th_err_format', 'bk_err_file', 'bk_err_format', 'bk_err_version']);
      final missing = used.where((k) => !strings['en']!.containsKey(k)).toList()..sort();
      expect(missing, isEmpty);
    });

    test('tf replaces placeholders and dates format in both languages', () {
      I18n.lang = 'en';
      expect(tf('wp_count', {'n': '3'}), '3 pictures');
      expect(formatDate(DateTime(2026, 11, 18)), 'Wednesday, November 18');
      expect(formatTime(DateTime(2026, 1, 1, 0, 5), false), '12:05');
      expect(formatTime(DateTime(2026, 1, 1, 13, 5), true), '13:05');
      I18n.lang = 'bn';
      expect(formatDate(DateTime(2026, 11, 18)), 'বুধবার, 18 নভেম্বর');
    });

    test('wallpaper names', () {
      I18n.lang = 'en';
      expect(wallpaperName('radha_krishna_3.jpg', true), 'Radha Krishna — Fire & Water');
      expect(wallpaperName('1731900000000_My_Trip.jpg', false), 'My Trip');
    });
  });

  group('palette', () {
    test('every builtin theme resolves in both modes', () {
      for (final th in builtinThemes) {
        for (final dark in [true, false]) {
          final p = Palette.resolve(th, dark, const Appearance());
          expect(p.dark, dark);
        }
      }
    });

    test('colour helpers match the desktop formulas', () {
      expect(mix('#000000', '#FFFFFF', 0.5), '#808080');
      expect(mix('#FFB800', '#FFB800', 0.3), '#FFB800');
      expect(colorHex(hexColor('#12ab9F')), '#12AB9F');
      expect(luminance('#FFFFFF'), closeTo(1, 1e-9));
      final light = deriveVariant(goldenColors, false);
      expect(light['glass'], '#FFFFFF');
      expect(light['accent'], '#FFB800');
    });

    test('appearance clamps out-of-range values', () {
      final a = Appearance.fromJson({'cardOpacity': 5, 'radius': -3, 'glow': 'x', 'wallpaperBackground': false});
      expect(a.cardOpacity, 0.95);
      expect(a.radius, 6);
      expect(a.glow, const Appearance().glow);
      expect(a.wallpaperBackground, isFalse);
    });
  });

  group('theme files', () {
    test('export → import round trip', () {
      final th = colorThemes[2];
      final json = exportThemeJson(th, 'Ocean');
      final back = parseThemeImport(utf8.encode(json));
      expect(back.name, 'Ocean');
      expect(back.mode, th.mode);
      expect(back.colors, th.colors);
    });

    test('accepts a theme file written by the Windows version (with BOM)', () {
      const desktop = '﻿{"format": "golden-glass-theme", "version": 1, "name": "Desk", "mode": "light",'
          ' "colors": {"accent": "#ff0000", "text": "#000000", "glow": "bad"}, "app": "Golden Glass Desktop"}';
      final th = parseThemeImport(utf8.encode(desktop));
      expect(th.mode, 'light');
      expect(th.colors['accent'], '#FF0000');
      expect(th.colors['glow'], goldenColors['glow']); // অবৈধ রং বাদ
    });

    test('rejects broken or foreign files', () {
      expect(() => parseThemeImport(utf8.encode('not json')), throwsA(isA<FormatException>()));
      expect(() => parseThemeImport(utf8.encode('{"format":"other","colors":{"accent":"#FFFFFF"}}')),
          throwsA(predicate((e) => e is FormatException && e.message == 'th_err_format')));
      expect(() => parseThemeImport(utf8.encode('{"format":"golden-glass-theme","colors":{}}')),
          throwsA(isA<FormatException>()));
      expect(() => parseThemeImport(List.filled(maxThemeImportBytes + 1, 32)), throwsA(isA<FormatException>()));
    });
  });

  group('app state', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<AppState> fresh() async {
      final s = AppState(prefs: await SharedPreferences.getInstance());
      return s;
    }

    test('settings survive a save/load cycle', () async {
      final a = await fresh();
      final id = a.saveCustomTheme(ThemeDef(id: '', name: 'Mine', mode: 'light', colors: colorsFromAccent('#3366FF', false)));
      a.applyTheme(id);
      a.setLook(a.look.copyWith(radius: 10));
      a.setFit('fit');
      a.setLang('en');
      final b = AppState(prefs: await SharedPreferences.getInstance());
      b.applySettings(jsonDecode((await SharedPreferences.getInstance()).getString('gg_state_v1')!));
      expect(b.themeId, id);
      expect(b.customThemes.single.name, 'Mine');
      expect(b.look.radius, 10);
      expect(b.wallpaperFit, 'fit');
      expect(b.lang, 'en');
    });

    test('garbage settings fall back to defaults', () async {
      final a = await fresh();
      a.applySettings({
        'themeId': 'nope',
        'auto': {'minutes': 7, 'target': 'moon'},
        'customThemes': [1, 'x', {'id': 'golden_glass', 'colors': {'accent': '#FFFFFF'}}],
        'storage': {'warn': 99, 'critical': 99},
      });
      expect(a.themeId, 'golden_glass');
      expect(a.autoMinutes, 60);
      expect(a.autoTarget, 'both');
      expect(a.customThemes, isEmpty); // builtin id নকল করা যাবে না
      expect(a.storageWarn, 50);
      expect(a.storageCritical, lessThan(a.storageWarn));
    });

    test('unique theme names', () async {
      final a = await fresh();
      I18n.lang = 'en';
      expect(a.uniqueThemeName('Golden Glass'), 'Golden Glass (2)');
      expect(a.uniqueThemeName('Fresh'), 'Fresh');
    });

    test('backup round trip and validation', () async {
      final a = await fresh();
      a.saveCustomTheme(ThemeDef(id: '', name: 'Backup me', mode: 'dark', colors: colorsFromAccent('#22CC88', true)));
      a.setDark(false);
      final backup = a.exportBackup();

      final b = await fresh();
      await b.importBackup(utf8.encode(backup));
      expect(b.customThemes.single.name, 'Backup me');
      expect(b.dark, isFalse);

      Future<void> bad(String s, String key) => expectLater(
          b.importBackup(utf8.encode(s)), throwsA(predicate((e) => e is FormatException && e.message == key)));
      await bad('{oops', 'bk_err_file');
      await bad('{"format":"golden-glass-theme","settings":{}}', 'bk_err_format');
      await bad('{"format":"$backupFormat","version":9,"settings":{}}', 'bk_err_version');
    });

    test('reset keeps language', () async {
      final a = await fresh();
      a.setLang('en');
      a.applyTheme('ocean_blue');
      a.resetToDefaults();
      expect(a.lang, 'en');
      expect(a.themeId, 'golden_glass');
    });
  });

  test('pubspec version matches appVersion', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(r'^version:\s*([0-9.]+)\+', multiLine: true).firstMatch(pubspec);
    expect(m?.group(1), appVersion);
  });
}

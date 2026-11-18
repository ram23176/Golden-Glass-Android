// থিম — অ্যাপের নিজস্ব UI-এর রং।
// Windows ভার্সনের app/services/theme_service.py-এর হুবহু Dart রূপ, তাই দুই ভার্সনে একই থিম
// একই রকম দেখায় এবং থিম ফাইল (.json) এক ভার্সন থেকে আরেক ভার্সনে import করা যায়।

import 'dart:convert';
import 'dart:ui';

const themeRoles = ['background', 'glass', 'accent', 'accent2', 'border', 'glow', 'button', 'text'];
const themeExportFormat = 'golden-glass-theme';
const maxThemeImportBytes = 64 * 1024;
final hexRe = RegExp(r'^#[0-9A-Fa-f]{6}$');

class ThemeDef {
  ThemeDef({
    required this.id,
    required this.mode,
    required this.colors,
    this.name = '',
    this.builtin = false,
    this.forceMode = false,
    this.variant = const {},
    this.deity,
  });

  /// দেবতার থিম হলে তাঁর ছবির ফোল্ডারের id (deityFolders দেখুন), নইলে null
  final String? deity;
  final String id;
  String name; // builtin থিমের নাম i18n থেকে আসে
  String mode; // dark | light
  Map<String, String> colors; // role → #RRGGBB
  final bool builtin;
  final bool forceMode; // প্রয়োগ করলে অ্যাপের মোডও বদলায়
  final Map<String, Map<String, String>> variant;

  ThemeDef copy() => ThemeDef(
        id: id,
        mode: mode,
        colors: Map.of(colors),
        name: name,
        builtin: builtin,
        forceMode: forceMode,
        variant: variant,
        deity: deity,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'mode': mode, 'colors': colors};

  static ThemeDef? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.isEmpty || builtinThemeIds.contains(id)) return null;
    final colors = sanitizeColors(raw['colors']);
    if (colors == null) return null;
    return ThemeDef(
      id: id,
      name: cleanName(raw['name'], 'Custom'),
      mode: raw['mode'] == 'light' ? 'light' : 'dark',
      colors: colors,
    );
  }
}

/// দেবতার ছবির ফোল্ডার (ক্রম অনুযায়ী দেখায়)। 'other' = কোনো দেবতার নয় এমন ছবি।
const deityFolders = ['ram_sita', 'hanuman', 'radha_krishna', 'shiva', 'durga', 'ganesh'];
const otherFolder = 'other';
const allFolders = [...deityFolders, otherFolder];

/// দেবতার থিম: প্রত্যেক দেবতার সাথে মানানসই রং + তাঁর ছবির ফোল্ডার
final List<ThemeDef> deityThemes = [
  // রাম-সীতা: গেরুয়া ও সোনালি
  ThemeDef(id: 'deity_ram_sita', deity: 'ram_sita', mode: 'dark', builtin: true, colors: {
    'background': '#1A1008', 'glass': '#2E1F10', 'accent': '#FF9933', 'accent2': '#E65C00',
    'border': '#FFC27A', 'glow': '#FF9933', 'button': '#FFAA4D', 'text': '#FFF4E6',
  }),
  // হনুমান: সিঁদুর-কমলা ও লাল
  ThemeDef(id: 'deity_hanuman', deity: 'hanuman', mode: 'dark', builtin: true, colors: {
    'background': '#1C0A06', 'glass': '#34150C', 'accent': '#FF5A1F', 'accent2': '#C2410C',
    'border': '#FF9A70', 'glow': '#FF6A2B', 'button': '#FF7A3D', 'text': '#FFF1EA',
  }),
  // রাধা-কৃষ্ণ: কৃষ্ণের ময়ূর-নীল ও রাধার গোলাপি
  ThemeDef(id: 'deity_radha_krishna', deity: 'radha_krishna', mode: 'dark', builtin: true, colors: {
    'background': '#071423', 'glass': '#10263D', 'accent': '#2E9BFF', 'accent2': '#E8489A',
    'border': '#8CC8FF', 'glow': '#3AA0FF', 'button': '#4DAAFF', 'text': '#EEF6FF',
  }),
  // শিব: ছাই-নীল, কৈলাসের বরফ
  ThemeDef(id: 'deity_shiva', deity: 'shiva', mode: 'dark', builtin: true, colors: {
    'background': '#0B1220', 'glass': '#18243A', 'accent': '#7DB4E6', 'accent2': '#4A5D8C',
    'border': '#A9C9EE', 'glow': '#9CC8F0', 'button': '#8DBEEA', 'text': '#EEF4FB',
  }),
  // দুর্গা: লাল ও সোনালি
  ThemeDef(id: 'deity_durga', deity: 'durga', mode: 'dark', builtin: true, colors: {
    'background': '#1C0709', 'glass': '#351015', 'accent': '#E11D48', 'accent2': '#F5B800',
    'border': '#FF8A9E', 'glow': '#FF2E5B', 'button': '#F43F5E', 'text': '#FFF0F2',
  }),
  // গণেশ: গাঁদা-হলুদ ও সিঁদুর
  ThemeDef(id: 'deity_ganesh', deity: 'ganesh', mode: 'dark', builtin: true, colors: {
    'background': '#1A1206', 'glass': '#33240B', 'accent': '#FFC107', 'accent2': '#E53935',
    'border': '#FFD966', 'glow': '#FFC107', 'button': '#FFCD38', 'text': '#FFF8E1',
  }),
];

/// সব তৈরি থিম: আগে দেবতার থিম, তারপর রঙের থিম
List<ThemeDef> get builtinThemes => [...deityThemes, ...colorThemes];

final List<ThemeDef> colorThemes = [
  ThemeDef(id: 'golden_glass', mode: 'dark', builtin: true, colors: {
    'background': '#14101F', 'glass': '#261C30', 'accent': '#FFB800', 'accent2': '#FF8C00',
    'border': '#FFBF4D', 'glow': '#FFB800', 'button': '#FFC21A', 'text': '#FFF7E8',
  }, variant: {
    'light': {'background': '#F4ECE2', 'glass': '#FFFFFF', 'text': '#2A1E12', 'border': '#D98C0D'},
  }),
  ThemeDef(id: 'royal_purple', mode: 'dark', builtin: true, colors: {
    'background': '#120B24', 'glass': '#24173F', 'accent': '#A855F7', 'accent2': '#6D28D9',
    'border': '#C4A1FF', 'glow': '#9B5CFF', 'button': '#B57BFF', 'text': '#F6F0FF',
  }),
  ThemeDef(id: 'ocean_blue', mode: 'dark', builtin: true, colors: {
    'background': '#07131F', 'glass': '#0F2537', 'accent': '#38BDF8', 'accent2': '#2563EB',
    'border': '#7DD3FC', 'glow': '#38BDF8', 'button': '#4CC6FA', 'text': '#EEF8FF',
  }),
  ThemeDef(id: 'emerald_green', mode: 'dark', builtin: true, colors: {
    'background': '#071A14', 'glass': '#0F2B22', 'accent': '#34D399', 'accent2': '#059669',
    'border': '#6EE7B7', 'glow': '#10B981', 'button': '#3EDBA3', 'text': '#ECFDF5',
  }),
  ThemeDef(id: 'rose_pink', mode: 'dark', builtin: true, colors: {
    'background': '#1F0B16', 'glass': '#34142A', 'accent': '#FF4FA3', 'accent2': '#E11D74',
    'border': '#FF9CCB', 'glow': '#FF4FA3', 'button': '#FF6BB3', 'text': '#FFF0F7',
  }),
  ThemeDef(id: 'dark_glass', mode: 'dark', builtin: true, forceMode: true, colors: {
    'background': '#0E0F13', 'glass': '#1E2028', 'accent': '#CBD5E1', 'accent2': '#64748B',
    'border': '#94A3B8', 'glow': '#E2E8F0', 'button': '#E2E8F0', 'text': '#F1F5F9',
  }),
  ThemeDef(id: 'light_glass', mode: 'light', builtin: true, forceMode: true, colors: {
    'background': '#EEF3FA', 'glass': '#FFFFFF', 'accent': '#3B82F6', 'accent2': '#06B6D4',
    'border': '#3B82F6', 'glow': '#60A5FA', 'button': '#3B82F6', 'text': '#1E293B',
  }),
];
final Set<String> builtinThemeIds = {for (final t in builtinThemes) t.id};

/// নতুন বা ভাঙা রঙের ফাঁকা জায়গা পূরণের ভিত্তি: Golden Glass
Map<String, String> get goldenColors => colorThemes.first.colors;

// ---------------- রঙের হিসাব ----------------

Color hexColor(String hex) => Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);

int _ch(double v) => (v * 255).round().clamp(0, 255);

String colorHex(Color c) =>
    '#${[c.r, c.g, c.b].map((v) => _ch(v).toRadixString(16).padLeft(2, '0')).join().toUpperCase()}';

String mix(String a, String b, double t) {
  final ca = hexColor(a), cb = hexColor(b);
  int m(double x, double y) => (_ch(x) + (_ch(y) - _ch(x)) * t).round();
  return colorHex(Color.fromARGB(255, m(ca.r, cb.r), m(ca.g, cb.g), m(ca.b, cb.b)));
}

Color withAlpha(String hex, double alpha) => hexColor(hex).withValues(alpha: alpha.clamp(0.0, 1.0));

double luminance(String hex) {
  final c = hexColor(hex);
  return (0.2126 * _ch(c.r) + 0.7152 * _ch(c.g) + 0.0722 * _ch(c.b)) / 255;
}

/// একটি মোডের রং থেকে অন্য মোডের রং (accent অক্ষত রেখে)।
Map<String, String> deriveVariant(Map<String, String> colors, bool toDark) {
  final c = Map.of(colors);
  final accent = c['accent']!;
  if (toDark) {
    c['background'] = mix(accent, '#000000', 0.90);
    c['glass'] = mix(accent, '#000000', 0.80);
    c['text'] = mix(accent, '#FFFFFF', 0.93);
    c['border'] = mix(accent, '#FFFFFF', 0.30);
  } else {
    c['background'] = mix(accent, '#FFFFFF', 0.90);
    c['glass'] = '#FFFFFF';
    c['text'] = mix(accent, '#000000', 0.86);
    c['border'] = mix(accent, '#000000', 0.15);
  }
  return c;
}

/// শুধু accent থেকে পুরো থিম (নতুন কাস্টম থিমের "স্বয়ংক্রিয় রং" বাটন)।
Map<String, String> colorsFromAccent(String accent, bool dark) {
  final base = <String, String>{
    'accent': accent,
    'accent2': mix(accent, '#000000', 0.25),
    'glow': accent,
    'button': mix(accent, '#FFFFFF', 0.12),
  };
  return deriveVariant({...goldenColors, ...base}, dark);
}

String cleanName(Object? raw, String fallback) {
  final s = raw is String ? raw.replaceAll(RegExp(r'[\x00-\x1f]'), '').trim() : '';
  final cut = s.length > 40 ? s.substring(0, 40) : s;
  return cut.isEmpty ? fallback : cut;
}

/// অবৈধ রং বাদ দিয়ে, না থাকা role-এ Golden Glass-এর রং বসায়। accent না থাকলে null।
Map<String, String>? sanitizeColors(Object? raw) {
  if (raw is! Map) return null;
  final out = Map.of(goldenColors);
  var hasAccent = false;
  for (final role in themeRoles) {
    final v = raw[role];
    if (v is String && hexRe.hasMatch(v.trim())) {
      out[role] = v.trim().toUpperCase();
      if (role == 'accent') hasAccent = true;
    }
  }
  return hasAccent ? out : null;
}

// ---------------- Import / Export (Windows ভার্সনের সাথে একই ফরম্যাট) ----------------

String exportThemeJson(ThemeDef theme, String displayName) {
  return const JsonEncoder.withIndent('  ').convert({
    'format': themeExportFormat,
    'version': 1,
    'name': displayName,
    'mode': theme.mode,
    'colors': {for (final r in themeRoles) r: theme.colors[r]!.toUpperCase()},
    'exported_at': DateTime.now().toUtc().toIso8601String(),
    'app': 'Golden Glass Android',
  });
}

/// যাচাই করে নতুন (id ছাড়া) থিম ফেরত দেয়; সমস্যা হলে FormatException(i18n key)।
ThemeDef parseThemeImport(List<int> bytes) {
  if (bytes.isEmpty || bytes.length > maxThemeImportBytes) throw const FormatException('th_err_file');
  Object? data;
  try {
    var text = utf8.decode(bytes);
    if (text.startsWith('﻿')) text = text.substring(1);
    data = jsonDecode(text);
  } catch (_) {
    throw const FormatException('th_err_file');
  }
  if (data is! Map || data['format'] != themeExportFormat) throw const FormatException('th_err_format');
  final colors = sanitizeColors(data['colors']);
  if (colors == null) throw const FormatException('th_err_format');
  return ThemeDef(
    id: '',
    name: cleanName(data['name'], 'Imported'),
    mode: data['mode'] == 'light' ? 'light' : 'dark',
    colors: colors,
  );
}

// ---------------- Appearance ----------------

class Appearance {
  const Appearance({
    this.cardOpacity = 0.60,
    this.radius = 18,
    this.glow = 1.0,
    this.animSpeed = 1.0,
    this.blur = 24,
    this.wallpaperBackground = true,
  });

  final double cardOpacity; // 0.30–0.95
  final double radius; // 6–28
  final double glow; // 0–1.5
  final double animSpeed; // 0.5–2
  final double blur; // 0–40
  final bool wallpaperBackground;

  static const limits = {
    'cardOpacity': [0.30, 0.95],
    'radius': [6.0, 28.0],
    'glow': [0.0, 1.5],
    'animSpeed': [0.5, 2.0],
    'blur': [0.0, 40.0],
  };

  Duration anim(int ms) => Duration(milliseconds: (ms / animSpeed).round());

  Appearance copyWith({
    double? cardOpacity,
    double? radius,
    double? glow,
    double? animSpeed,
    double? blur,
    bool? wallpaperBackground,
  }) =>
      Appearance(
        cardOpacity: cardOpacity ?? this.cardOpacity,
        radius: radius ?? this.radius,
        glow: glow ?? this.glow,
        animSpeed: animSpeed ?? this.animSpeed,
        blur: blur ?? this.blur,
        wallpaperBackground: wallpaperBackground ?? this.wallpaperBackground,
      );

  Map<String, dynamic> toJson() => {
        'cardOpacity': cardOpacity,
        'radius': radius,
        'glow': glow,
        'animSpeed': animSpeed,
        'blur': blur,
        'wallpaperBackground': wallpaperBackground,
      };

  static Appearance fromJson(Object? raw) {
    const d = Appearance();
    if (raw is! Map) return d;
    double v(String key, double def) {
      final x = raw[key];
      if (x is! num) return def;
      final l = limits[key]!;
      return x.toDouble().clamp(l[0], l[1]);
    }

    return Appearance(
      cardOpacity: v('cardOpacity', d.cardOpacity),
      radius: v('radius', d.radius).roundToDouble(),
      glow: v('glow', d.glow),
      animSpeed: v('animSpeed', d.animSpeed),
      blur: v('blur', d.blur).roundToDouble(),
      wallpaperBackground: raw['wallpaperBackground'] is bool ? raw['wallpaperBackground'] as bool : true,
    );
  }
}

// ---------------- সম্পূর্ণ রঙের তালিকা ----------------

class Palette {
  Palette._(this.dark, Map<String, Object> v)
      : background = v['background'] as Color,
        accent = v['accent'] as Color,
        accent2 = v['accent2'] as Color,
        accentLight = v['accentLight'] as Color,
        accentSoft = v['accentSoft'] as Color,
        glow = v['glow'] as Color,
        buttonTop = v['buttonTop'] as Color,
        buttonBottom = v['buttonBottom'] as Color,
        onAccent = v['onAccent'] as Color,
        text = v['text'] as Color,
        textMuted = v['textMuted'] as Color,
        accentText = v['accentText'] as Color,
        glass = v['glass'] as Color,
        glassStrong = v['glassStrong'] as Color,
        glassInput = v['glassInput'] as Color,
        popupFill = v['popupFill'] as Color,
        sheen = v['sheen'] as Color,
        divider = v['divider'] as Color,
        track = v['track'] as Color,
        border = v['border'] as Color,
        borderHover = v['borderHover'] as Color,
        overlayTop = v['overlayTop'] as Color,
        overlayBottom = v['overlayBottom'] as Color,
        bgGradA = v['bgGradA'] as Color,
        bgGradB = v['bgGradB'] as Color,
        bgGradC = v['bgGradC'] as Color;

  final bool dark;
  final Color background, accent, accent2, accentLight, accentSoft, glow, buttonTop, buttonBottom;
  final Color onAccent, text, textMuted, accentText, glass, glassStrong, glassInput, popupFill;
  final Color sheen, divider, track, border, borderHover, overlayTop, overlayBottom;
  final Color bgGradA, bgGradB, bgGradC;

  /// থিম + মোড + Appearance → সব রং (Windows ভার্সনের resolve()-এর মতো)।
  factory Palette.resolve(ThemeDef theme, bool dark, Appearance look) {
    final nativeDark = theme.mode == 'dark';
    var colors = Map.of(theme.colors);
    if (dark != nativeDark) {
      colors = deriveVariant(colors, dark);
      colors.addAll(theme.variant[dark ? 'dark' : 'light'] ?? const {});
    }
    final bg = colors['background']!, glass = colors['glass']!, text = colors['text']!;
    final accent = colors['accent']!, accent2 = colors['accent2']!, border = colors['border']!;
    final op = look.cardOpacity;
    const white = '#FFFFFF', black = '#000000';

    final p = <String, Object>{
      'background': hexColor(bg),
      'accent': hexColor(accent),
      'accent2': hexColor(accent2),
      'accentLight': hexColor(mix(accent, white, 0.35)),
      'accentSoft': withAlpha(accent, 0.16),
      'glow': hexColor(colors['glow']!),
      'buttonTop': hexColor(colors['button']!),
      'buttonBottom': hexColor(accent2),
      'onAccent':
          luminance(colors['button']!) > 0.55 ? hexColor(mix(colors['button']!, black, 0.86)) : hexColor(white),
      'text': hexColor(text),
    };
    if (dark) {
      p.addAll({
        'overlayTop': withAlpha(bg, 0.55),
        'overlayBottom': withAlpha(bg, 0.85),
        'glass': withAlpha(glass, op),
        'glassStrong': withAlpha(glass, (op + 0.22).clamp(0, 1)),
        'glassInput': withAlpha(black, 0.28),
        'popupFill': withAlpha(mix(glass, black, 0.25), 0.97),
        'sheen': withAlpha(white, 0.07),
        'divider': withAlpha(white, 0.08),
        'track': withAlpha(white, 0.12),
        'border': withAlpha(border, 0.30),
        'borderHover': withAlpha(border, 0.75),
        'textMuted': hexColor(mix(text, bg, 0.30)),
        'accentText': hexColor(mix(accent, white, 0.15)),
        'bgGradA': hexColor(mix(bg, accent2, 0.20)),
        'bgGradB': hexColor(mix(bg, accent, 0.14)),
        'bgGradC': hexColor(mix(bg, accent2, 0.32)),
      });
    } else {
      p.addAll({
        'overlayTop': withAlpha(bg, 0.70),
        'overlayBottom': withAlpha(bg, 0.88),
        'glass': withAlpha(glass, (op - 0.05).clamp(0.25, 1)),
        'glassStrong': withAlpha(glass, (op + 0.20).clamp(0, 1)),
        'glassInput': withAlpha(white, 0.70),
        'popupFill': withAlpha(mix(bg, white, 0.6), 0.98),
        'sheen': withAlpha(white, 0.45),
        'divider': withAlpha(black, 0.08),
        'track': withAlpha(black, 0.09),
        'border': withAlpha(border, 0.40),
        'borderHover': withAlpha(border, 0.80),
        'textMuted': hexColor(mix(text, bg, 0.40)),
        'accentText': hexColor(mix(accent, black, 0.35)),
        'bgGradA': hexColor(mix(bg, accent, 0.18)),
        'bgGradB': hexColor(mix(bg, accent2, 0.12)),
        'bgGradC': hexColor(mix(bg, accent, 0.30)),
      });
    }
    return Palette._(dark, p);
  }
}

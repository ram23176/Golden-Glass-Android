// কাচের মতো (glass) UI-এর ছোট ছোট অংশ — সব পেজে এগুলোই ব্যবহার হয়।

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/i18n.dart';
import '../core/palette.dart';

// ---------------- অবস্থা সব জায়গায় পৌঁছে দেওয়া ----------------

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

extension AppContext on BuildContext {
  AppState get app => AppScope.of(this);
  AppState get appRead => AppScope.read(this);
  Palette get pal => AppScope.of(this).palette;
  Appearance get look => AppScope.of(this).look;
}

// ---------------- Material থিম ----------------

ThemeData buildMaterialTheme(Palette p, Appearance look) {
  final brightness = p.dark ? Brightness.dark : Brightness.light;
  final radius = BorderRadius.circular(look.radius);
  final scheme = ColorScheme.fromSeed(seedColor: p.accent, brightness: brightness).copyWith(
    primary: p.accent,
    onPrimary: p.onAccent,
    secondary: p.accent2,
    surface: p.popupFill,
    onSurface: p.text,
  );
  final base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
    iconTheme: IconThemeData(color: p.text),
    dividerColor: p.divider,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(color: p.text, fontSize: 20, fontWeight: FontWeight.w700),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.popupFill,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: p.border)),
      titleTextStyle: TextStyle(color: p.text, fontSize: 19, fontWeight: FontWeight.w700),
      contentTextStyle: TextStyle(color: p.textMuted, fontSize: 15, height: 1.4),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.popupFill,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(look.radius + 6))),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.popupFill,
      contentTextStyle: TextStyle(color: p.text, fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: p.border)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onAccent : p.textMuted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : p.track),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : p.border),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.accent,
      inactiveTrackColor: p.track,
      thumbColor: p.accent,
      overlayColor: p.accentSoft,
      valueIndicatorColor: p.accent,
      valueIndicatorTextStyle: TextStyle(color: p.onAccent),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.glassInput,
      labelStyle: TextStyle(color: p.textMuted),
      hintStyle: TextStyle(color: p.textMuted),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.border)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.border)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.accent, width: 1.5)),
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: p.accent, selectionHandleColor: p.accent),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
  );
}

// ---------------- ব্যাকগ্রাউন্ড ----------------

class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = app.palette;
    final path = app.backgroundPath;
    final blur = app.look.blur;
    return Stack(fit: StackFit.expand, children: [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [p.bgGradA, p.background, p.bgGradB, p.bgGradC],
            stops: const [0, 0.4, 0.75, 1],
          ),
        ),
      ),
      if (path != null)
        RepaintBoundary(
          child: AnimatedSwitcher(
            duration: app.look.anim(500),
            child: ImageFiltered(
              key: ValueKey('$path|$blur'),
              enabled: blur > 0,
              imageFilter: ui.ImageFilter.blur(sigmaX: blur / 2, sigmaY: blur / 2, tileMode: TileMode.clamp),
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                cacheWidth: 720,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.overlayTop, p.overlayBottom],
          ),
        ),
      ),
    ]);
  }
}

/// পুশ করা (নতুন) পেজের কাঠামো: ব্যাকগ্রাউন্ড + স্বচ্ছ AppBar।
class GlassPage extends StatelessWidget {
  const GlassPage({super.key, required this.title, required this.child, this.actions});

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(child: AppBackground()),
      Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(title), actions: actions),
        body: SafeArea(top: false, child: child),
      ),
    ]);
  }
}

// ---------------- কার্ড / বাটন ----------------

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.onLongPress,
    this.active = false,
    this.strong = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool active;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final look = context.look;
    final r = BorderRadius.circular(look.radius);
    final fill = strong ? p.glassStrong : p.glass;
    return AnimatedContainer(
      duration: look.anim(220),
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.alphaBlend(p.sheen, fill), fill],
          stops: const [0, 0.55],
        ),
        border: Border.all(color: active ? p.borderHover : p.border, width: active ? 1.6 : 1),
        boxShadow: active && look.glow > 0
            ? [BoxShadow(color: p.glow.withValues(alpha: 0.35 * look.glow), blurRadius: 18 * look.glow)]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          onLongPress: onLongPress,
          splashColor: p.accentSoft,
          highlightColor: p.accentSoft,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class GlowButton extends StatelessWidget {
  const GlowButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.primary = true,
    this.busy = false,
    this.danger = false,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;
  final bool busy;
  final bool danger;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final look = context.look;
    final enabled = onPressed != null && !busy;
    final r = BorderRadius.circular(look.radius.clamp(8, 22));
    final fg = primary ? p.onAccent : (danger ? Colors.redAccent : p.text);
    return AnimatedOpacity(
      duration: look.anim(150),
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: r,
          gradient: primary
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: danger ? [Colors.redAccent, Colors.red.shade700] : [p.buttonTop, p.buttonBottom])
              : null,
          color: primary ? null : p.glassStrong,
          border: primary ? null : Border.all(color: danger ? Colors.redAccent.withValues(alpha: 0.6) : p.border),
          boxShadow: primary && enabled && look.glow > 0
              ? [
                  BoxShadow(
                    color: (danger ? Colors.redAccent : p.glow).withValues(alpha: 0.35 * look.glow),
                    blurRadius: 14 * look.glow,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: r,
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18, vertical: compact ? 9 : 13),
              child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                if (busy)
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                else if (icon != null)
                  Icon(icon, size: 19, color: fg),
                if (busy || icon != null) const SizedBox(width: 8),
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: compact ? 13.5 : 15)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(4, 20, 4, 10)});

  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: padding,
      child: Row(children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(colors: [p.accent, p.accent2], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        ?trailing,
      ]),
    );
  }
}

class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color, this.size = 42});

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final c = color ?? p.accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withValues(alpha: 0.16),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Icon(icon, color: c, size: size * 0.5),
    );
  }
}

class GlassBar extends StatelessWidget {
  const GlassBar({super.key, required this.value, this.color, this.height = 8});

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final c = color ?? p.accent;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(children: [
          Positioned.fill(child: ColoredBox(color: p.track)),
          TweenAnimationBuilder<double>(
            tween: Tween(end: value.clamp(0.0, 1.0)),
            duration: context.look.anim(600),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => FractionallySizedBox(
              widthFactor: v,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [c, Color.lerp(c, Colors.white, 0.25)!]),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class SwitchRow extends StatelessWidget {
  const SwitchRow({super.key, required this.title, this.subtitle, required this.value, required this.onChanged, this.icon});

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          if (icon != null) ...[Icon(icon, color: p.accentText, size: 22), const SizedBox(width: 12)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w600)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle!, style: TextStyle(color: p.textMuted, fontSize: 12.5)),
                ),
            ]),
          ),
          Switch(value: value, onChanged: onChanged),
        ]),
      ),
    );
  }
}

class SliderRow extends StatelessWidget {
  const SliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.format,
    this.divisions,
    this.onChangeEnd,
  });

  final String label;
  final double value, min, max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w600))),
          Text(format(value), style: TextStyle(color: p.accentText, fontWeight: FontWeight.w700)),
        ]),
      ),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    ]);
  }
}

/// কয়েকটি বিকল্পের মধ্যে একটি বাছাই (Chip সারি)।
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({super.key, required this.options, required this.value, required this.label, required this.onChanged});

  final List<T> options;
  final T value;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final look = context.look;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final o in options)
        GestureDetector(
          onTap: () => onChanged(o),
          child: AnimatedContainer(
            duration: look.anim(180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: o == value ? LinearGradient(colors: [p.buttonTop, p.buttonBottom]) : null,
              color: o == value ? null : p.glassInput,
              border: Border.all(color: o == value ? Colors.transparent : p.border),
            ),
            child: Text(
              label(o),
              style: TextStyle(
                color: o == value ? p.onAccent : p.text,
                fontWeight: o == value ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13.5,
              ),
            ),
          ),
        ),
    ]);
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 5, child: Text(label, style: TextStyle(color: p.textMuted, fontSize: 14))),
        Expanded(
          flex: 6,
          child: Text(value,
              textAlign: TextAlign.end, style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ---------------- বার্তা / নিশ্চিতকরণ ----------------

void showToast(BuildContext context, String message, {bool error = false}) {
  final p = context.appRead.palette;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline,
            color: error ? Colors.redAccent : p.accent, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ]),
      duration: const Duration(seconds: 3),
    ));
}

Future<bool> confirm(BuildContext context, String title, String message, {bool danger = false, String? ok}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('cancel'))),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok ?? t('ok'), style: TextStyle(color: danger ? Colors.redAccent : null, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return result ?? false;
}

// ---------------- সংখ্যা সাজানো ----------------

String formatBytes(num bytes) {
  // Android-এর Settings অ্যাপের মতো দশমিক একক (1 GB = 1000³ বাইট)
  if (bytes >= 1e12) return '${(bytes / 1e12).toStringAsFixed(2)} TB';
  if (bytes >= 1e9) return '${(bytes / 1e9).toStringAsFixed(bytes >= 1e11 ? 0 : 1)} GB';
  if (bytes >= 1e6) return '${(bytes / 1e6).toStringAsFixed(0)} MB';
  return '${(bytes / 1e3).toStringAsFixed(0)} KB';
}

String formatUptime(int ms) {
  final d = Duration(milliseconds: ms);
  final days = d.inDays, hours = d.inHours % 24, mins = d.inMinutes % 60;
  if (days > 0) return tf('uptime_dhm', {'d': '$days', 'h': '$hours', 'm': '$mins'});
  return tf('uptime_hm', {'h': '$hours', 'm': '$mins'});
}

String formatInterval(int minutes) {
  if (minutes < 60) return tf('min_n', {'n': '$minutes'});
  if (minutes < 1440) return tf('hour_n', {'n': '${minutes ~/ 60}'});
  return tf('day_n', {'n': '${minutes ~/ 1440}'});
}

/// খালি জায়গার শতাংশ অনুযায়ী রং (সবুজ / হলুদ / লাল)
Color storageColor(AppState app, double freePercent) {
  if (freePercent < app.storageCritical) return const Color(0xFFFF4D4F);
  if (freePercent < app.storageWarn) return const Color(0xFFFFB020);
  return const Color(0xFF34D399);
}

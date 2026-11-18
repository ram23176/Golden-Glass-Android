// রং বাছাইয়ের ডায়ালগ: তৈরি রঙের তালিকা + Hue/Saturation/Brightness স্লাইডার + HEX লেখা।

import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/palette.dart';
import 'components.dart';

const _presets = [
  '#FFB800', '#FF8C00', '#FF4FA3', '#E11D74', '#A855F7', '#6D28D9', '#38BDF8', '#2563EB',
  '#34D399', '#059669', '#F43F5E', '#FACC15', '#14101F', '#0E0F13', '#FFFFFF', '#1E293B',
];

Future<String?> showColorPicker(BuildContext context, String initial, String title) {
  return showDialog<String>(context: context, builder: (_) => _ColorPickerDialog(initial: initial, title: title));
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial, required this.title});

  final String initial;
  final String title;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor hsv;
  late TextEditingController hex;

  @override
  void initState() {
    super.initState();
    hsv = HSVColor.fromColor(hexColor(widget.initial));
    hex = TextEditingController(text: widget.initial.toUpperCase());
  }

  @override
  void dispose() {
    hex.dispose();
    super.dispose();
  }

  String get current => colorHex(hsv.toColor());

  void setHsv(HSVColor value) => setState(() {
        hsv = value;
        hex.text = current;
      });

  void setHex(String value) {
    final v = value.trim().startsWith('#') ? value.trim() : '#${value.trim()}';
    if (hexRe.hasMatch(v)) setState(() => hsv = HSVColor.fromColor(hexColor(v)));
  }

  Widget slider(String label, double value, double max, List<Color> colors, ValueChanged<double> onChanged) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: p.textMuted, fontSize: 12.5)),
        SizedBox(
          height: 36,
          child: Stack(alignment: Alignment.center, children: [
            Positioned(
              left: 12,
              right: 12,
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(colors: colors),
                  border: Border.all(color: p.border),
                ),
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbColor: Colors.white,
                trackHeight: 12,
              ),
              child: Slider(value: value, max: max, onChanged: onChanged),
            ),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: hsv.toColor(),
                  shape: BoxShape.circle,
                  border: Border.all(color: p.borderHover, width: 2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: hex,
                  maxLength: 7,
                  style: TextStyle(color: p.text, fontFamily: 'monospace'),
                  decoration: const InputDecoration(labelText: 'HEX', counterText: ''),
                  onChanged: setHex,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in _presets)
                GestureDetector(
                  onTap: () => setHsv(HSVColor.fromColor(hexColor(c))),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: hexColor(c),
                      shape: BoxShape.circle,
                      border: Border.all(color: current == c ? p.accent : p.border, width: current == c ? 2.5 : 1),
                    ),
                  ),
                ),
            ]),
            slider(t('cp_hue'), hsv.hue, 360, [
              for (var h = 0; h <= 360; h += 60) HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor(),
            ], (v) => setHsv(hsv.withHue(v))),
            slider(t('cp_saturation'), hsv.saturation, 1, [
              hsv.withSaturation(0).toColor(),
              hsv.withSaturation(1).toColor(),
            ], (v) => setHsv(hsv.withSaturation(v))),
            slider(t('cp_brightness'), hsv.value, 1, [
              Colors.black,
              hsv.withValue(1).toColor(),
            ], (v) => setHsv(hsv.withValue(v))),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t('cancel'))),
        TextButton(
          onPressed: () => Navigator.pop(context, current),
          child: Text(t('ok'), style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

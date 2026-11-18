// সব পেজ খুলে দেখে কোনো error / overflow হয় কিনা (বাংলা ও English, ডার্ক ও লাইট)।

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_glass/core/app_state.dart';
import 'package:golden_glass/core/i18n.dart';
import 'package:golden_glass/main.dart';
import 'package:golden_glass/services/wallpaper_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// টেস্টে আসল ফাইল লেখা/পড়া হয় না (fake clock-এ আসল I/O শেষ হয় না, আর PC-তে ফাইলও জমে না)
class FakeStore extends WallpaperStore {
  @override
  Future<void> init() async {}

  @override
  Future<List<WallpaperItem>> list() async => const [];
}

/// Android-এর native অংশের নকল উত্তর (টেস্টে আসল ফোন নেই)
const nativeChannel = MethodChannel('golden_glass/native');

Future<Object?> fakeNative(MethodCall call) async {
  switch (call.method) {
    case 'getBattery':
      return {'level': 76, 'charging': true, 'full': false, 'plugged': 'usb', 'health': 'good',
        'temperature': 31.5, 'voltage': 4100, 'technology': 'Li-ion'};
    case 'getMemory':
      return {'total': 8000000000, 'available': 3100000000, 'low': false};
    case 'getStorage':
      return [
        {'id': 'internal', 'kind': 'internal', 'label': null, 'total': 128000000000, 'free': 9000000000},
        {'id': 'ABCD', 'kind': 'removable', 'label': 'SanDisk SD card', 'total': 64000000000, 'free': 50000000000},
      ];
    case 'getDeviceInfo':
      return {'manufacturer': 'Google', 'model': 'Pixel Test', 'android': '16', 'sdk': 36, 'cores': 8,
        'abi': 'arm64-v8a', 'uptimeMs': 93784000, 'screen': '1080 × 2340'};
    case 'widgetCount':
      return 1;
    case 'canPinWidget':
      return true;
    default:
      return null;
  }
}

/// ঘড়ি প্রতি সেকেন্ডে বদলায়, তাই pumpAndSettle কখনো শেষ হয় না — নির্দিষ্ট সময় ধরে অপেক্ষা।
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  for (final lang in ['bn', 'en']) {
    for (final dark in [true, false]) {
      testWidgets('all pages render ($lang, dark=$dark)', (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 2.75;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(nativeChannel, fakeNative);

        final state = AppState(prefs: await SharedPreferences.getInstance(), store: FakeStore());
        await tester.pumpWidget(GoldenGlassApp(state: state));
        await state.load();
        state.setLang(lang);
        state.setDark(dark);
        await settle(tester);

        // নিচের ৫টি ট্যাব
        for (final key in ['nav_wallpapers', 'nav_themes', 'nav_system', 'nav_more', 'nav_home']) {
          await tester.tap(find.text(t(key)).last);
          await settle(tester);
          expect(tester.takeException(), isNull, reason: key);
        }

        // "আরও" থেকে খোলা পেজগুলো
        for (final key in ['appearance_title', 'widget_title', 'backup_title', 'settings_title']) {
          await tester.tap(find.text(t('nav_more')).last);
          await settle(tester);
          await tester.tap(find.text(t(key)).first);
          await settle(tester);
          expect(tester.takeException(), isNull, reason: key);
          await tester.pageBack();
          await settle(tester);
        }

        // থিম এডিটর + রং বাছাই
        await tester.tap(find.text(t('nav_themes')).last);
        await settle(tester);
        // একেবারে শেষে স্ক্রল — নইলে বাটনটা নিচের ভাসমান ট্যাব-বারের নিচে ঢাকা পড়ে
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -20000));
        await settle(tester);
        await tester.tap(find.text(t('th_create')));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'editor');
        await tester.tap(find.text(t('role_accent')));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'color picker');
        await tester.tap(find.text(t('cancel')));
        await settle(tester);
        await tester.pageBack();
        await settle(tester);

        // টাইমার বন্ধ করার জন্য গাছ সরিয়ে দেওয়া
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

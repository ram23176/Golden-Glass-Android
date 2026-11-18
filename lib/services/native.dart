// Android-এর native (Kotlin) অংশের সাথে যোগাযোগ।
// প্রতিটি ফাংশন ব্যর্থ হলে নিরাপদ মান ফেরত দেয় — অ্যাপ কখনো crash করবে না।

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Native {
  static const _ch = MethodChannel('golden_glass/native');

  static Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _ch.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null; // টেস্ট / অন্য প্ল্যাটফর্ম
    } on PlatformException catch (e) {
      debugPrint('Native.$method failed: ${e.message}');
      return null;
    }
  }

  static Future<Map<String, dynamic>> deviceInfo() async =>
      Map<String, dynamic>.from(await _call<Map>('getDeviceInfo') ?? const {});

  static Future<Map<String, dynamic>> battery() async =>
      Map<String, dynamic>.from(await _call<Map>('getBattery') ?? const {});

  static Future<Map<String, dynamic>> memory() async =>
      Map<String, dynamic>.from(await _call<Map>('getMemory') ?? const {});

  static Future<List<Map<String, dynamic>>> storage() async {
    final list = await _call<List>('getStorage') ?? const [];
    return [for (final e in list) Map<String, dynamic>.from(e as Map)];
  }

  /// target: home | lock | both;  fit: auto | fill | fit
  static Future<bool> setWallpaper(String path, String target, String fit) async =>
      await _call<bool>('setWallpaper', {'path': path, 'target': target, 'fit': fit}) ?? false;

  static Future<void> configurePool(List<String> paths, bool shuffle, String target, String fit) =>
      _call('configurePool', {'paths': paths, 'shuffle': shuffle, 'target': target, 'fit': fit});

  /// তালিকার পরের ওয়ালপেপার; সফল হলে তার পাথ।
  static Future<String?> nextWallpaper() => _call<String>('nextWallpaper');

  static Future<void> scheduleAuto(int minutes) => _call('scheduleAuto', {'minutes': minutes});

  static Future<void> cancelAuto() => _call('cancelAuto');

  static Future<String?> lastWallpaper() => _call<String>('getLastWallpaper');

  static Future<int> configureWidget({required int accent, required String free, required String next}) async =>
      await _call<int>('configureWidget', {'accent': accent, 'free': free, 'next': next}) ?? 0;

  static Future<int> widgetCount() async => await _call<int>('widgetCount') ?? 0;

  static Future<bool> canPinWidget() async => await _call<bool>('canPinWidget') ?? false;

  static Future<bool> pinWidget() async => await _call<bool>('pinWidget') ?? false;
}

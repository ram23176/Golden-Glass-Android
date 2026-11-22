// ওয়ালপেপার লাইব্রেরি: অ্যাপের সাথে আসা ছবি + ব্যবহারকারীর নিজের ছবি, দেবতা অনুযায়ী ফোল্ডারে।
// সব ছবি অ্যাপের নিজস্ব জায়গায় থাকে, তাই গ্যালারি থেকে মূল ছবি মুছলেও এখানে থেকে যায়।
//
//   wallpapers/bundled/<ফাইল>          অ্যাপের সাথে আসা ছবি (মোছা যায় না)
//   wallpapers/mine/<ফোল্ডার>/<ফাইল>   নিজের ছবি; ফোল্ডার = ram_sita, hanuman, … , other

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/palette.dart';

class WallpaperItem {
  const WallpaperItem({required this.id, required this.path, required this.bundled, required this.folder});

  final String id; // ফাইলের নাম — favorites এই নামে রাখা হয় (ফোল্ডার বদলালেও একই থাকে)
  final String path;
  final bool bundled;
  final String folder;
}

class WallpaperStore {
  WallpaperStore({this.rootOverride});

  /// টেস্টের জন্য: আসল অ্যাপ-ফোল্ডারের বদলে এই ফোল্ডার
  final Directory? rootOverride;

  /// assets/wallpapers/ -এর ছবি: ফাইল → (নামের i18n key, ফোল্ডার)
  static const bundled = {
    'radha_krishna_1.jpg': ('wp_radha_krishna_1', 'radha_krishna'),
    'radha_krishna_2.jpg': ('wp_radha_krishna_2', 'radha_krishna'),
    'radha_krishna_3.jpg': ('wp_radha_krishna_3', 'radha_krishna'),
  };
  static const _imageExt = {'.jpg', '.jpeg', '.png', '.webp', '.bmp', '.gif', '.heic', '.heif'};

  Directory? _bundledDir;
  Directory? _mineDir;

  Future<void> init() async {
    final root = rootOverride ?? await getApplicationSupportDirectory();
    _bundledDir = await Directory('${root.path}/wallpapers/bundled').create(recursive: true);
    _mineDir = await Directory('${root.path}/wallpapers/mine').create(recursive: true);
    for (final f in allFolders) {
      await Directory('${_mineDir!.path}/$f').create();
    }
    await _migrateLooseFiles();
    // আগের ভার্সনের যে ছবি আর অ্যাপের সাথে আসে না, সেগুলোর কপি মুছে জায়গা খালি করা
    await for (final e in _bundledDir!.list()) {
      if (e is File && !bundled.containsKey(_name(e.path))) await e.delete();
    }
    if (rootOverride != null) return; // টেস্টে asset নেই
    for (final name in bundled.keys) {
      final f = File('${_bundledDir!.path}/$name');
      if (await f.exists() && await f.length() > 0) continue;
      final data = await rootBundle.load('assets/wallpapers/$name');
      final tmp = File('${f.path}.part');
      await tmp.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
      await tmp.rename(f.path);
    }
  }

  /// আগের ভার্সনে (1.0.0) নিজের ছবি সরাসরি mine/-এ থাকত → "অন্যান্য" ফোল্ডারে সরানো
  Future<void> _migrateLooseFiles() async {
    await for (final e in _mineDir!.list()) {
      if (e is File && !e.path.endsWith('.part')) {
        await e.rename('${_mineDir!.path}/$otherFolder/${_name(e.path)}');
      }
    }
  }

  Future<List<WallpaperItem>> list() async {
    final items = <WallpaperItem>[];
    if (_bundledDir == null || _mineDir == null) return items;
    for (final MapEntry(key: name, value: (_, folder)) in bundled.entries) {
      final f = File('${_bundledDir!.path}/$name');
      if (rootOverride == null || f.existsSync()) {
        items.add(WallpaperItem(id: name, path: f.path, bundled: true, folder: folder));
      }
    }
    for (final folder in allFolders) {
      final dir = Directory('${_mineDir!.path}/$folder');
      if (!await dir.exists()) continue;
      final files = await dir.list().where((e) => e is File && !e.path.endsWith('.part')).cast<File>().toList();
      files.sort((a, b) => a.path.compareTo(b.path)); // নামের শুরুতে সময় আছে → পুরনো আগে
      for (final f in files) {
        items.add(WallpaperItem(id: _name(f.path), path: f.path, bundled: false, folder: folder));
      }
    }
    return items;
  }

  /// বাছাই করা ছবিগুলো নির্দিষ্ট ফোল্ডারে কপি করে; কয়টি যোগ হলো তা ফেরত দেয়।
  Future<int> importPicked(List<PlatformFile> files, String folder) async {
    if (_mineDir == null) return 0;
    final target = allFolders.contains(folder) ? folder : otherFolder;
    var added = 0;
    for (final file in files) {
      // কিছু গ্যালারি অ্যাপ এক্সটেনশন ছাড়া নাম দেয়; ছবি বাছাই করা হয়েছে image picker দিয়ে,
      // আর Android/Flutter ছবি চেনে ফাইলের ভেতরের ডেটা দেখে — তাই অচেনা হলে .jpg ধরা হয়।
      final rawExt = _ext(file.name);
      final known = _imageExt.contains(rawExt);
      final ext = known ? rawExt : '.jpg';
      final stem = known ? file.name.substring(0, file.name.length - rawExt.length) : file.name;
      final base = stem.replaceAll(RegExp(r'[^A-Za-z0-9_\-ঀ-৿]+'), '_');
      final safe = base.length > 40 ? base.substring(0, 40) : base;
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final dest = File('${_mineDir!.path}/$target/${stamp}_$safe$ext');
      final tmp = File('${dest.path}.part');
      try {
        final sink = tmp.openWrite();
        await sink.addStream(file.readAsByteStream());
        await sink.close();
        if (await tmp.length() == 0) {
          await tmp.delete();
          continue;
        }
        await tmp.rename(dest.path);
        added++;
      } catch (_) {
        if (await tmp.exists()) await tmp.delete();
      }
    }
    if (rootOverride == null) await FilePicker.clearTemporaryFiles();
    return added;
  }

  /// নিজের ছবি অন্য ফোল্ডারে সরানো; নতুন পাথ ফেরত দেয় (অ্যাপের ছবি সরানো যায় না)।
  Future<String?> move(WallpaperItem item, String folder) async {
    if (item.bundled || _mineDir == null || !allFolders.contains(folder) || folder == item.folder) return null;
    final f = File(item.path);
    if (!await f.exists()) return null;
    final moved = await f.rename('${_mineDir!.path}/$folder/${item.id}');
    return moved.path;
  }

  Future<bool> delete(WallpaperItem item) async {
    if (item.bundled) return false;
    final f = File(item.path);
    if (await f.exists()) await f.delete();
    return true;
  }

  static String _name(String path) => path.split(RegExp(r'[\\/]')).last;

  static String _ext(String name) {
    final i = name.lastIndexOf('.');
    return i < 0 ? '' : name.substring(i).toLowerCase();
  }
}

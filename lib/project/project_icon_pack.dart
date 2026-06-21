import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

import '../storage/local_store.dart';

class ProjectIconPack {
  static Map<String, dynamic>? _active;

  static bool get isActive => _active != null;

  static void setActive(Map<String, dynamic>? pack) {
    _active = pack;
  }

  static Map<String, dynamic>? get active => _active;

  static void activate({
    required Map<String, Uint8List> baseSheets,
    required Map<String, Uint8List> customIcons,
  }) {
    final pack = <String, dynamic>{
      'v': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'baseSheets': <String, String>{
        for (final e in baseSheets.entries) e.key: base64Encode(e.value),
      },
      'customPng': <String, String>{
        for (final e in customIcons.entries) e.key: base64Encode(e.value),
      },
    };

    setActive(pack);
  }
  static String _sheetLetterForKey(String k) {
    if (k.startsWith('T')) return 'T';
    if (k.startsWith('L')) return 'L';
    return 'R';
  }

  static int _indexForKey(String iconKey) {
    final m = RegExp(r'(\d\d)$').firstMatch(iconKey);
    final n = int.tryParse(m?.group(1) ?? '') ?? 1;
    return (n - 1).clamp(0, 8);
  }

  static Future<Uint8List> _cropFromSpriteSheetBytes(Uint8List sheetBytes, int idx0) async {
    final decoded = img.decodeImage(sheetBytes);
    if (decoded == null) {
      throw Exception('Could not decode sprite sheet bytes');
    }
    final tileW = (decoded.width / 3).floor();
    final tileH = (decoded.height / 3).floor();
    final row = idx0 ~/ 3;
    final col = idx0 % 3;
    final x = col * tileW;
    final y = row * tileH;
    final cropped = img.copyCrop(decoded, x: x, y: y, width: tileW, height: tileH);
    final png = img.encodePng(cropped);
    return Uint8List.fromList(png);
  }

  static Future<Uint8List> iconPngBytes(String iconKey) async {
    final k = iconKey.toUpperCase();

    final pack = _active;

    if (pack != null) {
      final custom = (pack['customPng'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      if (k.startsWith('C')) {
        final b64 = custom[k] as String?;
        if (b64 != null && b64.isNotEmpty) {
          return Uint8List.fromList(base64Decode(b64));
        }
        final bytes = await LocalStore.loadCustomIconPng(k);
        if (bytes != null && bytes.isNotEmpty) return bytes;
      }

      final baseSheets = (pack['baseSheets'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      final letter = _sheetLetterForKey(k);
      final b64Sheet = baseSheets[letter] as String?;
      if (b64Sheet != null && b64Sheet.isNotEmpty) {
        final sheetBytes = Uint8List.fromList(base64Decode(b64Sheet));
        final idx0 = _indexForKey(k);
        return _cropFromSpriteSheetBytes(sheetBytes, idx0);
      }
    }

    if (k.startsWith('C')) {
      final bytes = await LocalStore.loadCustomIconPng(k);
      if (bytes != null && bytes.isNotEmpty) return bytes;
    }

    final sheetPath = (k.startsWith('T'))
        ? 'assets/icons/icons_t.png'
        : (k.startsWith('L'))
            ? 'assets/icons/icons_l.png'
            : 'assets/icons/icons_r.png';

    final idx0 = _indexForKey(k);
    final data = await rootBundle.load(sheetPath);
    final sheetBytes = data.buffer.asUint8List();
    return _cropFromSpriteSheetBytes(sheetBytes, idx0);
  }

  static Future<Map<String, dynamic>> buildPackForProject(List<String> customKeys) async {
    final t = (await rootBundle.load('assets/icons/icons_t.png')).buffer.asUint8List();
    final l = (await rootBundle.load('assets/icons/icons_l.png')).buffer.asUint8List();
    final r = (await rootBundle.load('assets/icons/icons_r.png')).buffer.asUint8List();

    final custom = <String, String>{};
    for (final k in customKeys) {
      final kk = k.toUpperCase();
      if (!kk.startsWith('C')) continue;
      final bytes = await LocalStore.loadCustomIconPng(kk);
      if (bytes != null && bytes.isNotEmpty) {
        custom[kk] = base64Encode(bytes);
      }
    }

    return <String, dynamic>{
      'v': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'baseSheets': <String, String>{
        'T': base64Encode(t),
        'L': base64Encode(l),
        'R': base64Encode(r),
      },
      'customPng': custom,
    };
  }
}

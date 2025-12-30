import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../export/download.dart';
import 'project_bundle_io.dart';

class ProjectBundleShare {
  static Future<void> exportProjectJson(String chartName) async {
    final bundle = await ProjectBundleIO.buildFromStore(chartName);

    var safeName = chartName.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    safeName = safeName.replaceAll(RegExp(r'^_+|_+$'), '');
    if (safeName.isEmpty) safeName = 'rollchart';

    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final exportName = '${safeName}_$stamp';
    final filename = '$exportName.json';

    final obj = bundle.toJson();
    obj['name'] = exportName;
    const enc = JsonEncoder.withIndent('  ');
    final jsonText = enc.convert(obj);
    final bytes = Uint8List.fromList(utf8.encode(jsonText));

    if (kIsWeb) {
      saveBytesAsFile(bytes, filename, 'application/json');
      return;
    }

    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$filename');
    await f.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles([XFile(f.path)], text: 'Rollchart project JSON');
  }
}

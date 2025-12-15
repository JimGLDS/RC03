import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../models.dart';

class RollchartExporter {
  static String _csvEscape(String s) {
    final needs = s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r');
    if (!needs) return s;
    return '"${s.replaceAll('"', '""')}"';
  }

  static String buildCsv(List<RowDraft> rows) {
    final b = StringBuffer();
    b.writeln([
      'REC',
      'ODO',
      'SURFACE',
      'ICON',
      'TAGS',
      'RIGHT_NOTE',
      'ROAD_NO',
      'ROAD_NAME',
      'DESCR',
      'IS_RESET',
      'RESET_NAME',
    ].join(','));

    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      b.writeln([
        (i + 1).toString(),
        formatHundredths(r.odoHundredths),
        surfaceText(r.surface),
        r.iconKey,
        _csvEscape(r.tags),
        _csvEscape((r.rightNote ?? '')),
        _csvEscape((r.roadNo ?? '')),
        _csvEscape((r.roadName ?? '')),
        _csvEscape((r.descr ?? '')),
        r.isReset ? '1' : '0',
        _csvEscape((r.resetLabel ?? '')),
      ].join(','));
    }
    return b.toString();
  }

  static void downloadTextWeb(String filename, String mime, String text) {
    final bytes = utf8.encode(text);
    downloadBytesWeb(filename, mime, Uint8List.fromList(bytes));
  }

  static void downloadBytesWeb(String filename, String mime, Uint8List bytes) {
    final blob = html.Blob([bytes], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final a = html.AnchorElement(href: url)
      ..download = filename
      ..style.display = 'none';
    html.document.body!.children.add(a);
    a.click();
    a.remove();
    html.Url.revokeObjectUrl(url);
  }

  static String _sheetForKey(String iconKey) {
    if (iconKey.startsWith('T')) return 'assets/icons/icons_t.png';
    if (iconKey.startsWith('L')) return 'assets/icons/icons_l.png';
    return 'assets/icons/icons_r.png';
  }

  static int _indexForKey(String iconKey) {
    final m = RegExp(r'(\d\d)$').firstMatch(iconKey);
    final n = int.tryParse(m?.group(1) ?? '') ?? 1;
    return (n - 1).clamp(0, 8);
  }

  static Future<Uint8List> _iconPngBytes(String iconKey) async {
    final sheetPath = _sheetForKey(iconKey);
    final idx = _indexForKey(iconKey);

    final data = await rootBundle.load(sheetPath);
    final sheetBytes = data.buffer.asUint8List();
    final decoded = img.decodeImage(sheetBytes);
    if (decoded == null) throw Exception('Could not decode sprite sheet: $sheetPath');

    final tileW = (decoded.width / 3).floor();
    final tileH = (decoded.height / 3).floor();
    final row = idx ~/ 3;
    final col = idx % 3;
    final x = col * tileW;
    final y = row * tileH;

    final cropped = img.copyCrop(decoded, x: x, y: y, width: tileW, height: tileH);
    final png = img.encodePng(cropped);
    return Uint8List.fromList(png);
  }

  static String _rowRightText(RowDraft r) {
    final parts = <String>[];
    final road = [
      if ((r.roadNo ?? '').trim().isNotEmpty) r.roadNo!.trim(),
      if ((r.roadName ?? '').trim().isNotEmpty) r.roadName!.trim(),
    ].join(' ');
    if (road.isNotEmpty) parts.add(road);
    if ((r.rightNote ?? '').trim().isNotEmpty) parts.add(r.rightNote!.trim());
    return parts.join(' ');
  }

  static String _rowInfoText(RowDraft r) {
    final parts = <String>[];
    final right = _rowRightText(r);
    if (right.isNotEmpty) parts.add(right);
    if ((r.descr ?? '').trim().isNotEmpty) parts.add(r.descr!.trim());
    if (r.tags.trim().isNotEmpty) parts.add('[${r.tags.trim()}]');
    if (r.isReset) {
      final label = (r.resetLabel ?? '').trim();
      parts.add(label.isEmpty ? 'RESET' : 'RESET $label');
    }
    return parts.isEmpty ? '-' : parts.join(' • ');
  }

  static Future<Uint8List> buildThermalPdfBytes(List<RowDraft> rows) async {
    final doc = pw.Document();
    final iconCache = <String, pw.MemoryImage>{};

    Future<pw.MemoryImage> iconImage(String iconKey) async {
      if (iconCache.containsKey(iconKey)) return iconCache[iconKey]!;
      final pngBytes = await _iconPngBytes(iconKey);
      final mem = pw.MemoryImage(pngBytes);
      iconCache[iconKey] = mem;
      return mem;
    }

    const widthPts = 2.13 * 72.0; // 153.36 points
    const margin = 6.0;
    const rowH = 54.0;
    const headerH = 18.0;
    const footerH = 14.0;

    final heightPts = margin * 2 + headerH + footerH + rows.length * rowH;
    final pageFormat = PdfPageFormat(widthPts, heightPts);

    final items = <pw.Widget>[];

    items.add(
      pw.Container(
        height: headerH,
        alignment: pw.Alignment.centerLeft,
        child: pw.Text(
          'ROLLCHART',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ),
    );

    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final rec = (i + 1).toString();
      final odo = formatHundredths(r.odoHundredths);
      final surf = surfaceText(r.surface);
      final info = _rowInfoText(r);
      final icon = await iconImage(r.iconKey);

      items.add(
        pw.Container(
          height: rowH,
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(
                width: 48,
                child: pw.Row(
                  children: [
                    pw.SizedBox(width: 10, child: pw.Text(rec, style: const pw.TextStyle(fontSize: 7))),
                    pw.SizedBox(width: 6),
                    pw.Expanded(
                      child: pw.Text(odo, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Container(width: 26, height: 26, child: pw.Image(icon, fit: pw.BoxFit.contain)),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(surf, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text(info, maxLines: 1, overflow: pw.TextOverflow.clip, style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    items.add(
      pw.Container(
        height: footerH,
        alignment: pw.Alignment.centerLeft,
        child: pw.Text('END', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
      ),
    );

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(margin),
        build: (_) => pw.Column(children: items),
      ),
    );

    return doc.save();
  }

  static Future<void> exportCsvWeb(List<RowDraft> rows, {String filename = 'rollchart.csv'}) async {
    final csv = buildCsv(rows);
    downloadTextWeb(filename, 'text/csv;charset=utf-8', csv);
  }

  static Future<void> exportPdfWeb(List<RowDraft> rows, {String filename = 'rollchart_2.13in.pdf'}) async {
    final bytes = await buildThermalPdfBytes(rows);
    downloadBytesWeb(filename, 'application/pdf', bytes);
  }

  static bool get isWeb => kIsWeb;
}


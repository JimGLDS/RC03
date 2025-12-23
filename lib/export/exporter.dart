import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../storage/local_store.dart';
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
    // Compute mileage comps ONLY at CSV export time from current rows.
    final b = StringBuffer();

    // TRUE_MILE: continuous across RESET, in hundredths
    final trueHund = List<int>.filled(rows.length, 0);
    var baseOffset = 0;
    var prevTrue = 0;

    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final odo = r.odoHundredths ?? 0;

      if (i == 0) {
        baseOffset = 0;
            } else if (rows[i - 1].isReset) {
        // New section starts AFTER the reset row.
        // TRUE = prevTrue + ODO (ODO restarts near 0.00)
        baseOffset = prevTrue;
      }final t = odo + baseOffset;
      trueHund[i] = t;
      prevTrue = t;
    }

    final lastTrue = rows.isEmpty ? 0 : trueHund.last;    // SEG_MILES: segment length per row (in hundredths)
    // Rule: row1 segment = its ODO (no previous row).
    // For all others (including RESET rows): segment = TRUE[i] - TRUE[i-1].
    final segHund = List<int>.filled(rows.length, 0);
    for (var i = 0; i < rows.length; i++) {
      if (i == 0) {
        segHund[i] = trueHund[i];
      } else {
        segHund[i] = trueHund[i] - trueHund[i - 1];
      }
    }

// REMAINING_MILES: to end
    final remainingHund = List<int>.filled(rows.length, 0);
    for (var i = 0; i < rows.length; i++) {
      remainingHund[i] = lastTrue - trueHund[i];
    }

    // DIST_TO_NEXT_GAS: distance to next GAS row (blank if none)
    final nextGasDistHund = List<int?>.filled(rows.length, null);
    int? nextGasIndex;
    for (var i = rows.length - 1; i >= 0; i--) {
      if (nextGasIndex != null) {
        nextGasDistHund[i] = trueHund[nextGasIndex] - trueHund[i];
      } else {
        nextGasDistHund[i] = null;
      }
      final r = rows[i];
      if (r.isGas) nextGasIndex = i;
    }

    String fmtHundOrBlank(int? h) => (h == null) ? '' : formatHundredths(h);

    // Header (GAS last)
    b.writeln([
      'REC',
      'ODO',
      'SEG_MILES',
      'TRUE_MILE',
      'REMAINING_MILES',
      'DIST_TO_NEXT_GAS',
      'SURFACE',
      'ICON',
      'TAGS',
      'RIGHT_NOTE',
      'ROAD_NO',
      'ROAD_NAME',
      'DESCR',
      'IS_RESET',
      'RESET_NAME',
      'GAS',
    ].join(','));

    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final isGas = r.isGas;

      b.writeln([
        (i + 1).toString(),
        fmtHundOrBlank(r.odoHundredths),

        fmtHundOrBlank(segHund[i]),
        fmtHundOrBlank(trueHund[i]),
        fmtHundOrBlank(remainingHund[i]),
        fmtHundOrBlank(nextGasDistHund[i]),

        surfaceText(r.surface),
        r.iconKey,
        _csvEscape(r.tags),
        _csvEscape((r.rightNote ?? '')),
        (r.roadNo ?? ''),                // leave road numbers alone
        _csvEscape((r.roadName ?? '')),
        _csvEscape((r.descr ?? '')),
        r.isReset ? '1' : '0',
        _csvEscape((r.resetLabel ?? '')),
        isGas ? 'Y' : 'N',               // GAS last
      ].join(','));
    }
    final totalMiles = rows.isEmpty ? 0.0 : (trueHund.last / 100.0);

    String surfKey(SurfaceType s) {
      final t = surfaceText(s);
      if (t == 'IT' || t == '1T') return '1T';
      if (t == '2T' || t == 'DT' || t == 'GV' || t == 'PR') return t;
      return t;
    }

    final milesBy = <String, double>{ '2T': 0.0, '1T': 0.0, 'PR': 0.0, 'GV': 0.0, 'DT': 0.0 };

    for (var i = 0; i < rows.length; i++) {
      final m = segHund[i] / 100.0;
      final k = surfKey(rows[i].surface);
      if (milesBy.containsKey(k)) {
        milesBy[k] = (milesBy[k] ?? 0.0) + m;
      }
    }

    int pct(double miles) {
      if (totalMiles <= 0.0) return 0;
      return ((miles / totalMiles) * 100.0).round();
    }
    b.writeln('');
    b.writeln('SUMMARY');
    b.writeln('TOTAL_MILES,${totalMiles.toStringAsFixed(2)}');
    for (final k in ['2T', '1T', 'DT', 'GV', 'PR']) {
      final m = milesBy[k] ?? 0.0;
      b.writeln('${k}_MILES,${m.toStringAsFixed(2)},${pct(m)}%');
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
    final k = iconKey.toUpperCase();
    if (k.startsWith('C')) {
      final bytes = await LocalStore.loadCustomIconPng(k);
      if (bytes != null && bytes.isNotEmpty) return bytes;
    }
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
    final roadNo = (r.roadNo ?? '').trim();
    final roadName = (r.roadName ?? '').trim();
    final rightNote = (r.rightNote ?? '').trim();
    final descr = (r.descr ?? '').trim();

    // Tokenize tags, but normalize for logic (strip brackets).
    final raw = r.tags.trim().replaceAll('][', '] [');
    final rawTokens = raw.isEmpty ? <String>[] : raw.split(RegExp(r'\s+')).toList();

    String norm(String t) {
      var x = t.trim();
      if (x.startsWith('[') && x.endsWith(']') && x.length >= 2) {
        x = x.substring(1, x.length - 1).trim();
      }
      return x;
    }

    // Collect 'kept' tags exactly as they appeared (for _abbrTags),
    // but filter out internal markers and checkbox glyphs.
    final kept = <String>[];
    String? roadType;

    bool isMarkerToken(String n) {
      final u = n.toUpperCase();
      if (u == 'X' || u == 'XBOX' || u == 'X-BOX' || u == 'X_BOX') return true;
      // common glyph markers that sometimes leak in as tokens
      if (n == '?' || n == '?' || n == '?' || n == '•' || n == '·') return true;
      return false;
    }

    for (final t in rawTokens) {
      final n = norm(t);
      if (n.isEmpty) continue;
      if (isMarkerToken(n)) continue;

      final u = n.toUpperCase();
      if (roadType == null && (u == 'SM' || u == 'ORV' || u == 'FS' || u == 'RR')) {
        roadType = u;
        continue;
      }

      // Preserve token verbatim so _abbrTags can expand [DG]/[VDG]/etc.
      kept.add(t.trim());
    }

    // If truly nothing meaningful exists (no road info, no notes, no descr, no real tags, not reset): print dash
    if (!r.isReset &&
        roadType == null &&
        roadNo.isEmpty &&
        roadName.isEmpty &&
        rightNote.isEmpty &&
        descr.isEmpty &&
        kept.isEmpty) {
      return '-';
    }

    final bits = <String>[];

    final leadParts = <String>[];
    if (roadType != null) leadParts.add(roadType!);
    if (roadNo.isNotEmpty) leadParts.add(roadNo);
    if (roadName.isNotEmpty) leadParts.add(roadName);
    final lead = leadParts.join(' ');
    if (lead.isNotEmpty) bits.add(lead);

    if (rightNote.isNotEmpty) bits.add(rightNote);
    if (descr.isNotEmpty) bits.add(descr);

    final tagsOut = kept.join(' ').trim();
    if (tagsOut.isNotEmpty) bits.add(tagsOut);

    if (r.isReset) {
      final label = (r.resetLabel ?? '').trim();
      bits.add(label.isEmpty ? 'RESET' : 'RESET ');
    }

    return bits.isEmpty ? '-' : bits.join(' • ');
  }

  static Future<Uint8List> buildThermalPdfBytes(List<RowDraft> rows, {required String chartName}) async {
    recomputeRollchartDerived(rows);
    final doc = pw.Document();
    final iconCache = <String, pw.MemoryImage>{};

    Future<pw.MemoryImage> iconImage(String iconKey) async {
      final cacheKey = iconKey.toUpperCase();
      if (iconCache.containsKey(cacheKey)) return iconCache[cacheKey]!;
      final pngBytes = await _iconPngBytes(cacheKey);
      final mem = pw.MemoryImage(pngBytes);
      iconCache[cacheKey] = mem;
      return mem;
    }

    const widthPts = 2.13 * 72.0; // 153.36 points
    const margin = 6.0;
    const rowH = 54.0;
    const headerH = 34.0;
    const footerH = 14.0;
    const coverH = 470.0;
    const endH = 360.0;
    final resetBarCountPdf = rows.where((r) => r.isReset || r.isGas).length;
    final hasAnyGasPdf = rows.any((r) => r.isGas);
    final heightPts = margin * 2 + coverH + headerH + footerH + rows.length * rowH + endH + (resetBarCountPdf * rowH) + 72.0 + (hasAnyGasPdf ? 32.0 : 0.0);
    

    String _abbrTags(String s) {
      // Expand bracketed abbreviations to full phrases for thermal PDF output.
      return s
          .replaceAll('[VDG]', 'Very Dim Grassy')
          .replaceAll('[DG]', 'Dim grassy')
          .replaceAll('[OBS]', 'Obscure')
          .replaceAll('[XC!!]', 'XC!!')
          .replaceAll('[XC]', 'XC!!')

          // Also handle unbracketed abbreviations, just in case
          .replaceAll('VDG', 'Very Dim Grassy')
          .replaceAll('DG', 'Dim grassy')
          .replaceAll('OBS', 'Obscure')
          .replaceAll('?', '')
          .replaceAll('?', '')
          .replaceAll('?', '')
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll(RegExp(r'\bXC(?:!!)?\b'), 'XC!!');
      // XC!! stays XC!!
    }

    final items = <pw.Widget>[];


    // TRUE_MILE (PDF): continuous across RESET, in hundredths
    final trueHundPdf = List<int>.filled(rows.length, 0);
    var baseOffsetPdf = 0;
    var prevTruePdf = 0;

    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final odo = r.odoHundredths ?? 0;

      if (i == 0) {
        baseOffsetPdf = 0;
      } else if (rows[i - 1].isReset) {
        baseOffsetPdf = prevTruePdf;
      }

      final t = odo + baseOffsetPdf;
      trueHundPdf[i] = t;
      prevTruePdf = t;
    }    // SEG_MILES (PDF): per-row segment (hundredths)
    // Rule: row1 segment = its ODO (no previous row).
    // For all others (including RESET rows): segment = TRUE[i] - TRUE[i-1].
    final segHundPdf = List<int>.filled(rows.length, 0);
    for (var i = 0; i < rows.length; i++) {
      if (i == 0) {
        segHundPdf[i] = trueHundPdf[i];
      } else {
        segHundPdf[i] = trueHundPdf[i] - trueHundPdf[i - 1];
      }
    }


final nextGasDistHundPdf = List<int?>.filled(rows.length, null);
int? nextGasIndexPdf;
for (var i = rows.length - 1; i >= 0; i--) {
  if (nextGasIndexPdf != null) {
    nextGasDistHundPdf[i] = trueHundPdf[nextGasIndexPdf] - trueHundPdf[i];
  } else {
    nextGasDistHundPdf[i] = null;
  }
  if (rows[i].isGas) nextGasIndexPdf = i;
}

int? firstGasIndexPdf;
for (var i = 0; i < rows.length; i++) {
  if (rows[i].isGas) { firstGasIndexPdf = i; break; }
}

    int warnFromStartPdf = 0;
    {
      int? firstResetIdxPdf;
      for (var i = 0; i < rows.length; i++) {
        if (rows[i].isReset || rows[i].isGas) { firstResetIdxPdf = i; break; }
      }
      final end = firstResetIdxPdf ?? rows.length;
      var n = 0;
      for (var k = 0; k < end; k++) {
        final s = _rowInfoText(rows[k]);
        if (RegExp(r'\bXC(?:!!)?\b').hasMatch(s)) n++;
      }
      warnFromStartPdf = n;
    }


final warnNextReset = List<int>.filled(rows.length, 0);
bool _hasXc(RowDraft rr) {
  final s = _rowInfoText(rr);
  return RegExp(r'\bXC(?:!!)?\b').hasMatch(s);
}
for (var i = 0; i < rows.length; i++) {
  if (!(rows[i].isReset || rows[i].isGas)) continue;
  var j = i + 1;
  while (j < rows.length && !(rows[j].isReset || rows[j].isGas)) { j++; }
  var n = 0;
  for (var k = i + 1; k < j; k++) {
    if (_hasXc(rows[k])) n++;
  }
  warnNextReset[i] = n;

    int warnFromStartPdf = 0;
    {
      int? firstResetIdxPdf;
      for (var i = 0; i < rows.length; i++) {
        if (rows[i].isReset || rows[i].isGas) { firstResetIdxPdf = i; break; }
      }
      final end = firstResetIdxPdf ?? rows.length;
      var n = 0;
      for (var k = 0; k < end; k++) {
        if (_hasXc(rows[k])) n++;
      }
      warnFromStartPdf = n;
    }

}

String _fmtMiles1(int? hund) {
  if (hund == null) return '';
  return (hund / 100.0).toStringAsFixed(1);
}
String _fmtMiles2(double miles) => miles.toStringAsFixed(2);

final totalMiles = rows.isEmpty ? 0.0 : (trueHundPdf.last / 100.0);
    double _totalMiles() {
      if (rows.isEmpty) return 0.0;
      final first = rows.first.odoHundredths;
      final last = rows.last.odoHundredths;
      final delta = (last - first).clamp(0, 99999999);
      return delta / 100.0;
    }


    double _segMiles(int a, int b) {
      final d = b - a;
      if (d <= 0) return 0.0;
      return d / 100.0;
    }

    String _abbrSurf(SurfaceType s) {
      final t = surfaceText(s);
      if (t == '2T') return '2T';
      if (t == 'DT') return 'DT';
      if (t == 'GV') return 'GV';
      if (t == 'IT') return 'IT';
      if (t == 'PR') return 'PR';
      return t;
    }

    final milesBy = <String, double>{ '2T': 0.0, 'PR': 0.0, 'GV': 0.0, 'DT': 0.0, '1T': 0.0 };

        for (var i = 0; i < rows.length; i++) {
      if (rows[i].isReset) continue;
      final m = segHundPdf[i] / 100.0;
      final k = _abbrSurf(rows[i].surface);
      milesBy[k] = (milesBy[k] ?? 0.0) + m;
    }

    int _pct(double miles) {
      if (totalMiles <= 0.0) return 0;
      return ((miles / totalMiles) * 100.0).round();
    }

    items.add(pw.Container(height: 72));

    items.add(
      pw.Container(
        height: coverH,
        padding: const pw.EdgeInsets.only(top: 6),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(chartName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text(totalMiles.toStringAsFixed(2) + ' Miles', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 14),
            pw.Text('Please Ride Safe & Courteous!', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Slow & Quiet Near Residences!', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Slow near other people!', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 14),
            pw.Text('Warning!', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Use of this guide is at your own risk. There are hazards and other items not listed and they will be encountered by you.\\n\\n'
                  'This course includes public roads, highways and trails - conditions of these are beyond the control of those that developed this guide. You are responsible for your actions and your compliance with any applicable laws.\\n',
                  style: const pw.TextStyle(fontSize: 7),
                ),
                pw.Text(
                  'By using this guide, you agree to not hold the developers liable for any type of misfortune you experience.',
                  style: const pw.TextStyle(fontSize: 7, decoration: pw.TextDecoration.underline),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'If you do not agree, dispose of this guide immediately!',
                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, fontStyle: pw.FontStyle.italic),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Text('_______________________', style: const pw.TextStyle(fontSize: 8)),
            pw.SizedBox(height: 10),
            pw.Text('Legend -', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, fontStyle: pw.FontStyle.italic)),
            pw.SizedBox(height: 6),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(children: [
                  pw.SizedBox(width: 34, child: pw.Text('!', style: const pw.TextStyle(fontSize: 7))),
                  pw.Expanded(child: pw.Text('Caution/Danger!', style: const pw.TextStyle(fontSize: 7))),
                ]),
                pw.Row(children: [
                  pw.SizedBox(width: 34, child: pw.Text('!!', style: const pw.TextStyle(fontSize: 7))),
                  pw.Expanded(child: pw.Text('Danger/Severe!', style: const pw.TextStyle(fontSize: 7))),
                ]),
                pw.Row(children: [
                  pw.SizedBox(width: 34, child: pw.Text('!!!', style: const pw.TextStyle(fontSize: 7))),
                  pw.Expanded(child: pw.Text('Danger/Extreme!', style: const pw.TextStyle(fontSize: 7))),
                ]),
                pw.Row(children: [
                  pw.SizedBox(width: 34, child: pw.Text('X TC !!', style: const pw.TextStyle(fontSize: 7))),
                  pw.Expanded(child: pw.Text('Trail Crossing', style: const pw.TextStyle(fontSize: 7))),
                ]),
                pw.Row(children: [
                  pw.SizedBox(width: 34, child: pw.Text('1T', style: const pw.TextStyle(fontSize: 7))),
                  pw.Expanded(child: pw.Text('Single Track Trail', style: const pw.TextStyle(fontSize: 7))),
                ]),
                pw.Row(children: [
                  pw.SizedBox(width: 34, child: pw.Text('2T', style: const pw.TextStyle(fontSize: 7))),
                  pw.Expanded(child: pw.Text('Two Track', style: const pw.TextStyle(fontSize: 7))),
                ]),
                pw.Row(children: [
                  pw.SizedBox(width: 34, child: pw.Text('DT', style: const pw.TextStyle(fontSize: 7))),
                  pw.Expanded(child: pw.Text('Dirt Road', style: const pw.TextStyle(fontSize: 7))),
                ]),
                pw.Row(children: [
                  pw.SizedBox(width: 34, child: pw.Text('GV', style: const pw.TextStyle(fontSize: 7))),
                  pw.Expanded(child: pw.Text('Gravel Road', style: const pw.TextStyle(fontSize: 7))),
                ]),
                pw.Row(children: [
                  pw.SizedBox(width: 34, child: pw.Text('PR', style: const pw.TextStyle(fontSize: 7))),
                  pw.Expanded(child: pw.Text('Paved Road', style: const pw.TextStyle(fontSize: 7))),
                ]),
                pw.Row(children: [
                  pw.SizedBox(width: 34, child: pw.Text('MCCCT', style: const pw.TextStyle(fontSize: 7))),
                  pw.Expanded(child: pw.Text('MI Cross Country Cycle', style: const pw.TextStyle(fontSize: 7))),
                ]),
                pw.Row(children: [
                  pw.SizedBox(width: 34, child: pw.Text('ORV', style: const pw.TextStyle(fontSize: 7))),
                  pw.Expanded(child: pw.Text('ORV Trail/Route', style: const pw.TextStyle(fontSize: 7))),
                ]),
                pw.Row(children: [
                  pw.SizedBox(width: 34, child: pw.Text('SM', style: const pw.TextStyle(fontSize: 7))),
                  pw.Expanded(child: pw.Text('Snowmobile / SMORV', style: const pw.TextStyle(fontSize: 7))),
                ]),
                pw.Row(children: [
                  pw.SizedBox(width: 34, child: pw.Text('PL', style: const pw.TextStyle(fontSize: 7))),
                  pw.Expanded(child: pw.Text('Power Line', style: const pw.TextStyle(fontSize: 7))),
                ]),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Text('Note -', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.Text('On any intersection pictograph, always enter from the bottom vertical line.', style: const pw.TextStyle(fontSize: 7)),
          ],
        ),
      ),
    );
    items.add(
      pw.Container(
        height: headerH,
        alignment: pw.Alignment.centerLeft,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text('_______________________', style: const pw.TextStyle(fontSize: 8)),
            pw.SizedBox(height: 2),
            pw.Text(
              'START - HAVE A BLAST !!',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );    if (firstGasIndexPdf != null) {
      final d = trueHundPdf[firstGasIndexPdf!];
      items.add(
        pw.Container(
          height: 16,
          alignment: pw.Alignment.center,
          child: pw.Text(_fmtMiles1(d) + ' miles to next gas', style: const pw.TextStyle(fontSize: 7)),
        ),
      );

      items.add(
        pw.Container(
          height: 12,
          alignment: pw.Alignment.center,
          child: pw.Text('Warnings before first reset: ' + warnFromStartPdf.toString(), style: const pw.TextStyle(fontSize: 7)),
        ),
      );

      items.add(
        pw.Container(
          height: 2,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 0.8)),
          ),
        ),
      );
    }
for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final rec = (i + 1).toString();
      final odo = formatHundredths(r.odoHundredths);
      final surf = surfaceText(r.surface);
      final info = _rowInfoText(r);

      final hasMeaningful =
          (r.roadNo ?? '').trim().isNotEmpty ||
          (r.roadName ?? '').trim().isNotEmpty ||
          (r.rightNote ?? '').trim().isNotEmpty ||
          (r.descr ?? '').trim().isNotEmpty ||
          RegExp(r'\b(DG|VDG|OBS|XC!!|XC|SM|ORV|FS|RR)\b').hasMatch(info);
      final infoOut = hasMeaningful ? info : '-';

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
                width: 58,
                child: pw.Row(
                  children: [
                    pw.SizedBox(width: 16, child: pw.Text(rec, style: const pw.TextStyle(fontSize: 7))),
                    pw.SizedBox(width: 6),
                    pw.Expanded(
                      child: pw.Text(odo, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Container(width: 39, height: 39, child: pw.Image(icon, fit: pw.BoxFit.contain)),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(surf, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text(_abbrTags(infoOut), style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      final isResetEffective = r.isReset || r.isGas;
      if (isResetEffective) {
        final milesSoFar = (trueHundPdf[i] / 100.0);
        final milesToGo = (totalMiles - milesSoFar).clamp(0.0, 99999999.0);
        final gasDist = nextGasDistHundPdf[i];
        final isLastGas = r.isGas && gasDist == null;

        items.add(
          pw.Container(
            height: rowH,
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
            ),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                if (r.isGas)
                  pw.Text(
                    isLastGas ? 'This is Last Gas' : (_fmtMiles1(gasDist) + ' miles to next gas'),
                    style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic),
                    textAlign: pw.TextAlign.center,
                  ),
                if (r.isGas) pw.SizedBox(height: 2),
                pw.Text(
                  (((r.resetLabel ?? '').trim().isEmpty) ? 'Reset' : ('Reset ' + (r.resetLabel ?? '').trim())),
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Warnings during next reset: ' + warnNextReset[i].toString(),
                  style: const pw.TextStyle(fontSize: 7),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  _fmtMiles2(milesSoFar) + ' miles, ' + _fmtMiles2(milesToGo) + ' to go.',
                  style: const pw.TextStyle(fontSize: 7),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }
    }
    items.add(
      pw.Container(
        height: endH,
        padding: const pw.EdgeInsets.only(top: 10),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('End of Course - well done!', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text(chartName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text(totalMiles.toStringAsFixed(2) + ' Miles', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 10),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(children: [
                  pw.SizedBox(width: 16, child: pw.Text('2T', style: const pw.TextStyle(fontSize: 8))),
                  pw.SizedBox(width: 52, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text((milesBy['2T'] ?? 0.0).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8)))),
                  pw.SizedBox(width: 8),
                  pw.SizedBox(width: 22, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_pct(milesBy['2T'] ?? 0.0).toString() + '%', style: const pw.TextStyle(fontSize: 8)))),
                ]),
                pw.Row(children: [
                  pw.SizedBox(width: 16, child: pw.Text('PR', style: const pw.TextStyle(fontSize: 8))),
                  pw.SizedBox(width: 52, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text((milesBy['PR'] ?? 0.0).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8)))),
                  pw.SizedBox(width: 8),
                  pw.SizedBox(width: 22, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_pct(milesBy['PR'] ?? 0.0).toString() + '%', style: const pw.TextStyle(fontSize: 8)))),
                ]),
                pw.Row(children: [
                  pw.SizedBox(width: 16, child: pw.Text('GV', style: const pw.TextStyle(fontSize: 8))),
                  pw.SizedBox(width: 52, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text((milesBy['GV'] ?? 0.0).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8)))),
                  pw.SizedBox(width: 8),
                  pw.SizedBox(width: 22, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_pct(milesBy['GV'] ?? 0.0).toString() + '%', style: const pw.TextStyle(fontSize: 8)))),
                ]),
                pw.Row(children: [
                  pw.SizedBox(width: 16, child: pw.Text('DT', style: const pw.TextStyle(fontSize: 8))),
                  pw.SizedBox(width: 52, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text((milesBy['DT'] ?? 0.0).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8)))),
                  pw.SizedBox(width: 8),
                  pw.SizedBox(width: 22, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_pct(milesBy['DT'] ?? 0.0).toString() + '%', style: const pw.TextStyle(fontSize: 8)))),
                ]),
                pw.Row(children: [
                  pw.SizedBox(width: 16, child: pw.Text('1T', style: const pw.TextStyle(fontSize: 8))),
                  pw.SizedBox(width: 52, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text((milesBy['1T'] ?? 0.0).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8)))),
                  pw.SizedBox(width: 8),
                  pw.SizedBox(width: 22, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_pct(milesBy['1T'] ?? 0.0).toString() + '%', style: const pw.TextStyle(fontSize: 8)))),
                ]),
              ],
            ),
            pw.SizedBox(height: 108),
            pw.Container(
              height: 2,
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(width: 0.5)),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text('          Cut Here', style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
      ),
    );

    items.add(
      pw.Container(
        height: footerH,
        alignment: pw.Alignment.centerLeft,
        child: pw.Text('END', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
      ),
    );
    final pageFormat = PdfPageFormat(widthPts, heightPts);

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
    recomputeRollchartDerived(rows);
    final csv = buildCsv(rows);
    downloadTextWeb(filename, 'text/csv;charset=utf-8', csv);
  }

  static Future<void> exportPdfWeb(List<RowDraft> rows, {String filename = 'rollchart_2.13in.pdf', required String chartName}) async {
    recomputeRollchartDerived(rows);
    final bytes = await buildThermalPdfBytes(rows, chartName: chartName);
    downloadBytesWeb(filename, 'application/pdf', bytes);
  }

  static bool get isWeb => kIsWeb;
}




































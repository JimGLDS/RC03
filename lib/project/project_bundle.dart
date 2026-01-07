import 'dart:convert';
import 'dart:typed_data';

import '../models.dart';

/// Project JSON bundle (v1).
///
/// Goal:
/// - Export/import a complete rollchart project as a single JSON file
/// - Freeze icon assets inside the project (base sheets + custom Cxx icons)
///
/// JSON shape (v1):
/// {
///   "schema": "rollchart.project.v1",
///   "exportedAt": "2025-12-29T12:34:56.000Z",
///   "name": "My Rollchart",
///   "isDone": true,
///   "rows": [ {RowDraft map}, ... ],
///   "icons": {
///     "baseSheets": { "T": "<b64png>", "L": "<b64png>", "R": "<b64png>" },
///     "custom": { "C01": "<b64png>", "C02": "<b64png>", ... }
///   }
/// }
class ProjectBundleV1 {
  static const String schemaId = 'rollchart.project.v1';

  final String name;
  final bool isDone;
  final List<RowDraft> rows;

  /// Base sprite sheets as PNG bytes (3x3), keyed by "T","L","R"
  final Map<String, Uint8List> baseSheets;

  /// Custom icons as PNG bytes, keyed by "C01".."C99"
  final Map<String, Uint8List> customIcons;

  final String exportedAtIso;

  ProjectBundleV1({
    required this.name,
    required this.isDone,
    required this.rows,
    required this.baseSheets,
    required this.customIcons,
    required this.exportedAtIso,
  });

  // ---------- Row serialization (keep in sync with LocalStore) ----------
  static Map<String, dynamic> _rowToMap(RowDraft r) => {
        'odoHundredths': r.odoHundredths,
        'surface': r.surface.index,
        'iconKey': r.iconKey,
        'tags': r.tags,
        'rightNote': r.rightNote,
        'roadName': r.roadName,
        'roadNo': r.roadNo,
        'descr': r.descr,
        'isReset': r.isReset,
        'resetLabel': r.resetLabel,
        'isGas': r.isGas,
        'gasOdoHundredths': r.gasOdoHundredths,
        'segHundredthsFromPrev': r.segHundredthsFromPrev,
      };

  static RowDraft _rowFromMap(Map<String, dynamic> m) => RowDraft(
        odoHundredths: (m['odoHundredths'] ?? 0) as int,
        surface: SurfaceType.values[(m['surface'] ?? 0) as int],
        iconKey: (m['iconKey'] ?? 'T01') as String,
        tags: (m['tags'] ?? '') as String,
        rightNote: m['rightNote'] as String?,
        roadName: m['roadName'] as String?,
        roadNo: m['roadNo'] as String?,
        descr: m['descr'] as String?,
        isReset: (m['isReset'] ?? false) as bool,
        resetLabel: m['resetLabel'] as String?,
        isGas: (m['isGas'] ?? false) as bool,
        gasOdoHundredths: m['gasOdoHundredths'] as int?,
        segHundredthsFromPrev: m['segHundredthsFromPrev'] as int?,
      );

  // ---------- Base64 helpers ----------
  static String _b64(Uint8List bytes) => base64Encode(bytes);
  static Uint8List _unb64(String s) => Uint8List.fromList(base64Decode(s));

  Map<String, dynamic> toJson() {
    final sheetsOut = <String, String>{};
    for (final e in baseSheets.entries) {
      final k = e.key.toUpperCase().trim();
      sheetsOut[k] = _b64(e.value);
    }

    final customOut = <String, String>{};
    for (final e in customIcons.entries) {
      final k = e.key.toUpperCase().trim();
      customOut[k] = _b64(e.value);
    }

    return {
      'schema': schemaId,
      'exportedAt': exportedAtIso,
      'name': name,
      'isDone': isDone,
      'rows': rows.map(_rowToMap).toList(),
      'icons': {
        'baseSheets': sheetsOut,
        'custom': customOut,
      },
    };
  }

  String toJsonString({bool pretty = false}) {
    final obj = toJson();
    if (!pretty) return jsonEncode(obj);
    const enc = JsonEncoder.withIndent('  ');
    return enc.convert(obj);
  }

  static ProjectBundleV1 fromJson(Map<String, dynamic> m) {
    final schema = (m['schema'] ?? '') as String;
    if (schema != schemaId) {
      throw FormatException('Unsupported project schema: ');
    }

    final name = (m['name'] ?? '') as String;
    final isDone = (m['isDone'] ?? false) as bool;
    final exportedAt = (m['exportedAt'] ?? '') as String;

    final rowsRaw = (m['rows'] as List<dynamic>? ?? const []);
    final rows = rowsRaw
        .map((e) => _rowFromMap((e as Map).cast<String, dynamic>()))
        .toList();

    final icons = (m['icons'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final baseSheetsRaw =
        (icons['baseSheets'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final customRaw =
        (icons['custom'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    final baseSheets = <String, Uint8List>{};
    for (final e in baseSheetsRaw.entries) {
      final k = e.key.toUpperCase().trim();
      final v = (e.value ?? '') as String;
      if (v.isEmpty) continue;
      baseSheets[k] = _unb64(v);
    }

    final customIcons = <String, Uint8List>{};
    for (final e in customRaw.entries) {
      final k = e.key.toUpperCase().trim();
      final v = (e.value ?? '') as String;
      if (v.isEmpty) continue;
      customIcons[k] = _unb64(v);
    }

    return ProjectBundleV1(
      name: name,
      isDone: isDone,
      rows: rows,
      baseSheets: baseSheets,
      customIcons: customIcons,
      exportedAtIso: exportedAt,
    );
  }

  static ProjectBundleV1 fromJsonString(String jsonText) {
    final obj = (jsonDecode(jsonText) as Map).cast<String, dynamic>();
    return fromJson(obj);
  }
}

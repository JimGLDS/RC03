import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';

class LocalStore {
  static String _key(String chartName) => 'rollchart:${chartName.toLowerCase()}';

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
      );

  static Future<void> saveChart({
    required String chartName,
    required bool isDone,
    required List<RowDraft> rows,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final payload = {
      'isDone': isDone,
      'rows': rows.map(_rowToMap).toList(),
      'savedAt': DateTime.now().toIso8601String(),
    };
    await sp.setString(_key(chartName), jsonEncode(payload));
  }

  static Future<({bool isDone, List<RowDraft> rows})?> loadChart(String chartName) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key(chartName));
    if (raw == null || raw.trim().isEmpty) return null;

    final m = jsonDecode(raw) as Map<String, dynamic>;
    final isDone = (m['isDone'] ?? false) as bool;

    final list = (m['rows'] as List<dynamic>? ?? const []);
    final rows = list.map((e) => _rowFromMap(e as Map<String, dynamic>)).toList();

    return (isDone: isDone, rows: rows);
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';

class RollchartMeta {
  final String name;
  final bool isDone;
  final String updatedAtIso;

  RollchartMeta({required this.name, required this.isDone, required this.updatedAtIso});

  Map<String, dynamic> toJson() => {
        'name': name,
        'isDone': isDone,
        'updatedAtIso': updatedAtIso,
      };

  static RollchartMeta fromJson(Map<String, dynamic> m) => RollchartMeta(
        name: (m['name'] ?? '') as String,
        isDone: (m['isDone'] ?? false) as bool,
        updatedAtIso: (m['updatedAtIso'] ?? '') as String,
      );
}

class LocalStore {
  static const String _indexKey = 'rollchart:index:v1';

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

  static Future<void> _writeIndex(List<RollchartMeta> metas) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_indexKey, jsonEncode(metas.map((m) => m.toJson()).toList()));
  }

  static Future<void> _upsertMeta(String name, bool isDone) async {
    final metas = await listCharts();
    final nowIso = DateTime.now().toIso8601String();
    final idx = metas.indexWhere((m) => m.name.toLowerCase() == name.toLowerCase());
    if (idx >= 0) {
      metas[idx] = RollchartMeta(name: metas[idx].name, isDone: isDone, updatedAtIso: nowIso);
    } else {
      metas.add(RollchartMeta(name: name, isDone: isDone, updatedAtIso: nowIso));
    }
    await _writeIndex(metas);
  }

  // ---------- SELF-HEALING INDEX ----------
  static Future<List<RollchartMeta>> listCharts() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_indexKey);

    if (raw != null && raw.trim().isNotEmpty) {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      final metas = list
          .map((e) => RollchartMeta.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      metas.sort((a, b) => b.updatedAtIso.compareTo(a.updatedAtIso));
      return metas;
    }

    // Index missing/empty: rebuild by scanning keys.
    final keys = sp.getKeys();
    final chartKeys = keys
        .where((k) => k.startsWith('rollchart:') && k != _indexKey)
        .toList();

    final metas = <RollchartMeta>[];

    for (final k in chartKeys) {
      // key format: rollchart:<lowercase name>
      final lowerName = k.substring('rollchart:'.length);
      final payloadRaw = sp.getString(k);
      if (payloadRaw == null || payloadRaw.trim().isEmpty) continue;

      try {
        final m = (jsonDecode(payloadRaw) as Map).cast<String, dynamic>();
        final isDone = (m['isDone'] ?? false) as bool;
        final savedAt = (m['savedAt'] ?? '') as String;
        final updatedAtIso = savedAt.isNotEmpty ? savedAt : DateTime.now().toIso8601String();

        // We don't know original casing; show lowercase for now.
        metas.add(RollchartMeta(name: lowerName, isDone: isDone, updatedAtIso: updatedAtIso));
      } catch (_) {
        // Skip bad entries
      }
    }

    metas.sort((a, b) => b.updatedAtIso.compareTo(a.updatedAtIso));
    await _writeIndex(metas);
    return metas;
  }

  // ---------- CRUD ----------
  static Future<void> deleteChart(String chartName) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key(chartName));
    final metas = await listCharts();
    metas.removeWhere((m) => m.name.toLowerCase() == chartName.toLowerCase());
    await _writeIndex(metas);
  }

  static Future<void> renameChart(String oldName, String newName) async {
    final loaded = await loadChart(oldName);
    if (loaded == null) return;

    await saveChart(chartName: newName, isDone: loaded.isDone, rows: loaded.rows);
    await deleteChart(oldName);
    await _upsertMeta(newName, loaded.isDone);
  }

  static Future<void> duplicateChart(String fromName, String toName) async {
    final loaded = await loadChart(fromName);
    if (loaded == null) return;
    await saveChart(chartName: toName, isDone: false, rows: loaded.rows);
  }

  // ---------- PAYLOAD ----------
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
    await _upsertMeta(chartName, isDone);
  }

  static Future<({bool isDone, List<RowDraft> rows})?> loadChart(String chartName) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key(chartName));
    if (raw == null || raw.trim().isEmpty) return null;

    final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
    final isDone = (m['isDone'] ?? false) as bool;

    final list = (m['rows'] as List<dynamic>? ?? const []);
    final rows = list.map((e) => _rowFromMap((e as Map).cast<String, dynamic>())).toList();

    return (isDone: isDone, rows: rows);
  }
}



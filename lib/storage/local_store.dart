import 'dart:convert';
import 'dart:typed_data';
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

  // ---------- CUSTOM ICON STORAGE ----------
  // Stores flattened custom icons (PNG bytes) in SharedPreferences as base64.
  static const String _customIconIndexKey = 'icons:custom:index:v1';
  static const String _customIconPngPrefix = 'icons:custom:png:';

  static String _customPngKey(String iconKey) => _customIconPngPrefix + iconKey.toUpperCase();

  static Future<List<String>> listCustomIconKeys() async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_customIconIndexKey) ?? <String>[];
    final out = <String>[];
    for (final k in list) {
      final kk = k.toUpperCase();
      if (kk.startsWith('C')) out.add(kk);
    }
    out.sort();
    return out;
  }

  static Future<String> nextCustomIconKey() async {
    final keys = await listCustomIconKeys();
    var maxNum = 0;
    for (final kk in keys) {
      final tail = (kk.length >= 3) ? kk.substring(1) : '';
      final n = int.tryParse(tail) ?? 0;
      if (n > maxNum) maxNum = n;
    }
    final next = (maxNum + 1).clamp(1, 99);
    final nn = next.toString().padLeft(2, '0');
    return 'C' + nn;
  }

  static Future<void> saveCustomIconPng(String iconKey, Uint8List pngBytes) async {
    final sp = await SharedPreferences.getInstance();
    final k = iconKey.toUpperCase();
    final b64 = base64Encode(pngBytes);
    await sp.setString(_customPngKey(k), b64);

    final list = (sp.getStringList(_customIconIndexKey) ?? <String>[])
        .map((e) => e.toUpperCase())
        .toList();

    if (!list.contains(k)) list.add(k);
    list.sort();
    await sp.setStringList(_customIconIndexKey, list);
  }

  static Future<Uint8List?> loadCustomIconPng(String iconKey) async {
    final sp = await SharedPreferences.getInstance();
    final k = iconKey.toUpperCase();
    final b64 = sp.getString(_customPngKey(k));
    if (b64 == null || b64.isEmpty) return null;
    try {
      final bytes = base64Decode(b64);
      return Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteCustomIcon(String iconKey) async {
    final sp = await SharedPreferences.getInstance();
    final k = iconKey.toUpperCase();
    await sp.remove(_customPngKey(k));

    final list = (sp.getStringList(_customIconIndexKey) ?? <String>[])
        .map((e) => e.toUpperCase())
        .where((e) => e != k)
        .toList();
    list.sort();
    await sp.setStringList(_customIconIndexKey, list);
  }

  static Future<void> clearAllCustomIcons() async {
    final sp = await SharedPreferences.getInstance();
    final keys = await listCustomIconKeys();
    for (final k in keys) {
      await sp.remove(_customPngKey(k));
    }
    await sp.remove(_customIconIndexKey);
  }
  // ---------- PROJECT ICON PACK ----------
  // Stores a per-project snapshot of base sprite sheets + any custom icons needed by the project.
  // This prevents future app updates from changing the look of an old project.
  static String _packKey(String chartName) => 'rollchart:pack:' + chartName.toLowerCase();

  static Future<void> saveProjectIconPack(String chartName, Map<String, dynamic> pack) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_packKey(chartName), jsonEncode(pack));
  }

  static Future<Map<String, dynamic>?> loadProjectIconPack(String chartName) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_packKey(chartName));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteProjectIconPack(String chartName) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_packKey(chartName));
  }

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
    await sp.remove(_packKey(chartName));

    final metas = await listCharts();
    metas.removeWhere((m) => m.name.toLowerCase() == chartName.toLowerCase());
    await _writeIndex(metas);
  }
  static Future<void> renameChart(String oldName, String newName) async {
    final loaded = await loadChart(oldName);
    if (loaded == null) return;

    final pack = await loadProjectIconPack(oldName);
    if (pack != null) {
      await saveProjectIconPack(newName, pack);
    }

    await saveChart(chartName: newName, isDone: loaded.isDone, rows: loaded.rows);
    await deleteChart(oldName);
    await _upsertMeta(newName, loaded.isDone);
  }
  static Future<void> duplicateChart(String fromName, String toName) async {
    final loaded = await loadChart(fromName);
    if (loaded == null) return;

    final pack = await loadProjectIconPack(fromName);
    if (pack != null) {
      await saveProjectIconPack(toName, pack);
    }

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












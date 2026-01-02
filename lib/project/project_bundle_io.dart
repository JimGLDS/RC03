import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../models.dart';
import '../storage/local_store.dart';
import 'project_bundle.dart';
import 'project_icon_pack.dart';

/// Build / apply ProjectBundleV1 from app state.
class ProjectBundleIO {
  // ---------- EXPORT ----------

  /// Build a bundle from an existing stored project.
  static Future<ProjectBundleV1> buildFromStore(String chartName) async {
    final loaded = await LocalStore.loadChart(chartName);
    if (loaded == null) {
      throw StateError('Project not found: ');
    }

    // Prefer frozen per-project pack for export (created on create/open/import).
    // If missing (legacy), fall back to current assets (do NOT save/overwrite here).
    final pack = await LocalStore.loadProjectIconPack(chartName);

    final baseSheets = <String, Uint8List>{};

    final baseSheetsRaw =
        (pack?['baseSheets'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    for (final e in baseSheetsRaw.entries) {
      final k = e.key.toUpperCase().trim();
      final v = (e.value ?? '') as String;
      if (v.isEmpty) continue;
      baseSheets[k] = Uint8List.fromList(base64Decode(v));
    }

    if (baseSheets.isEmpty) {
      baseSheets['T'] = await _loadAssetPng('assets/icons/icons_t.png');
      baseSheets['L'] = await _loadAssetPng('assets/icons/icons_l.png');
      baseSheets['R'] = await _loadAssetPng('assets/icons/icons_r.png');
    }

    // Load all custom icons currently present
    final customKeys = await LocalStore.listCustomIconKeys();
    final customIcons = <String, Uint8List>{};
    for (final k in customKeys) {
      final bytes = await LocalStore.loadCustomIconPng(k);
      if (bytes != null && bytes.isNotEmpty) {
        customIcons[k] = bytes;
      }
    }

    return ProjectBundleV1(
      name: chartName,
      isDone: loaded.isDone,
      rows: loaded.rows,
      baseSheets: baseSheets,
      customIcons: customIcons,
      exportedAtIso: DateTime.now().toIso8601String(),
    );
  }

  // ---------- IMPORT ----------

  /// Apply a bundle into storage (creates or overwrites project).
  static Future<void> applyToStore(ProjectBundleV1 bundle) async {
    // Save chart rows + done state
    await LocalStore.saveChart(
      chartName: bundle.name,
      isDone: bundle.isDone,
      rows: bundle.rows,
    );

    // Activate project-specific icon pack
    ProjectIconPack.activate(
      baseSheets: bundle.baseSheets,
      customIcons: bundle.customIcons,
    );

    // Persist the frozen pack for this project (import path)
    if (ProjectIconPack.active != null) {
      await LocalStore.saveProjectIconPack(bundle.name, ProjectIconPack.active!);
    }
  }

  // ---------- helpers ----------

  static Future<Uint8List> _loadAssetPng(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }
}

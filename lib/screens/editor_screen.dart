import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets/icon_sprite.dart';
import 'wizard/screen1.dart';
import '../export/exporter.dart';
import '../storage/local_store.dart';

class RollChartEditorScreen extends StatefulWidget {
  final String chartName;
  const RollChartEditorScreen({super.key, required this.chartName});

  @override
  State<RollChartEditorScreen> createState() => _RollChartEditorScreenState();
}

class _RollChartEditorScreenState extends State<RollChartEditorScreen> {

  @override
  void initState() {
    super.initState();
    _restore();
  }

  final List<RowDraft> rows = [];
  SurfaceType carrySurface = SurfaceType.DT;
  bool isComplete = false;

  bool _loaded = false;

  Future<void> _restore() async {
    final loaded = await LocalStore.loadChart(widget.chartName);
    if (!mounted) return;
    setState(() {
      rows.clear();
      if (loaded != null) {
        rows.addAll(loaded.rows);
        isComplete = loaded.isDone;
        carrySurface = rows.isEmpty ? SurfaceType.DT : rows.last.surface;
      } else {
        isComplete = false;
        carrySurface = SurfaceType.DT;
      }
      _loaded = true;
    });
  }

  Future<void> _save() async {
    if (!_loaded) return;
    await LocalStore.saveChart(chartName: widget.chartName, isDone: isComplete, rows: rows);
  }
// New row ODO must increase, except the first row AFTER a RESET row.
  int? minOdoForNextRowExclusive() {
    if (rows.isEmpty) return null;
    if (rows.last.isReset) return null;
    return rows.last.odoHundredths;
  }

  // Collect existing reset names (optionally excluding an index while editing).
  List<String> existingResetNames({int? excludeIndex}) {
    final out = <String>[];
    for (var i = 0; i < rows.length; i++) {
      if (excludeIndex != null && i == excludeIndex) continue;
      final r = rows[i];
      if (r.isReset) {
        final s = (r.resetLabel ?? '').trim();
        if (s.isNotEmpty) out.add(s);
      }
    }
    return out;
  }

  String sheetForKey(String iconKey) {
    if (iconKey.startsWith('T')) return 'assets/icons/icons_t.png';
    if (iconKey.startsWith('L')) return 'assets/icons/icons_l.png';
    return 'assets/icons/icons_r.png';
  }

  int indexForKey(String iconKey) {
    final m = RegExp(r'(\d\d)$').firstMatch(iconKey);
    final n = int.tryParse(m?.group(1) ?? '') ?? 1;
    return (n - 1).clamp(0, 8);
  }

  String rollText(RowDraft r) {
    final bits = <String>[];

    final right = [
      if ((r.roadNo ?? '').trim().isNotEmpty) r.roadNo!.trim(),
      if ((r.roadName ?? '').trim().isNotEmpty) r.roadName!.trim(),
      if ((r.rightNote ?? '').trim().isNotEmpty) r.rightNote!.trim(),
    ].join(' ');
    if (right.isNotEmpty) bits.add(right);

    if ((r.descr ?? '').trim().isNotEmpty) bits.add(r.descr!.trim());
    if (r.tags.trim().isNotEmpty) bits.add('[${r.tags.trim()}]');

    if (r.isReset) {
      final label = (r.resetLabel ?? '').trim();
      bits.add(label.isEmpty ? 'RESET' : 'RESET $label');
    }

    return bits.isEmpty ? 'â€”' : bits.join(' â€¢ ');
  }

  Future<void> editRow(int index) async {
    final r = rows[index];

    // ODO min bound: must be > previous unless previous is RESET
    int? minExclusive;
    if (index > 0 && !rows[index - 1].isReset) {
      minExclusive = rows[index - 1].odoHundredths;
    }

    // ODO max bound: must be < next unless THIS row is RESET (because next row can restart)
    int? maxExclusive;
    if (!r.isReset && index < rows.length - 1) {
      maxExclusive = rows[index + 1].odoHundredths;
    }

    final updated = await Navigator.push<RowDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => Screen1(
          recNo: index + 1,
          carrySurface: r.surface,
          minOdoHundredthsExclusive: minExclusive,
          maxOdoHundredthsExclusive: maxExclusive,
          existingResetNames: existingResetNames(excludeIndex: index),
          initialDraft: RowDraft.clone(r),
        ),
      ),
    );

    if (updated != null) {
      setState(() {
        rows[index] = updated;
        carrySurface = rows.isEmpty ? SurfaceType.DT : rows.last.surface;
      });
      await _save();
}
  }

  Future<void> insertRowAt(int index) async {
    // Insert BEFORE index. Must fall between neighbors.
    int? minExclusive;
    if (index > 0 && !rows[index - 1].isReset) {
      minExclusive = rows[index - 1].odoHundredths;
    }
    final maxExclusive = rows[index].odoHundredths;

    final draft = await Navigator.push<RowDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => Screen1(
          recNo: index + 1,
          carrySurface: rows[index].surface,
          minOdoHundredthsExclusive: minExclusive,
          maxOdoHundredthsExclusive: maxExclusive,
          existingResetNames: existingResetNames(),
          initialDraft: null,
        ),
      ),
    );

    if (draft != null) {
      setState(() {
        rows.insert(index, draft);
      });
      await _save();
}
  }

  Future<void> deleteRowAt(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete row?'),
        content: Text('Delete row ${index + 1}? This cannot be undone.'),
        actions: [
          IconButton(
            tooltip: isComplete ? 'Mark as In Progress' : 'Mark as Done',
            icon: Icon(isComplete ? Icons.check_circle : Icons.check_circle_outline),
            onPressed: () async {
              setState(() => isComplete = !isComplete);
              await _save();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(isComplete ? 'Saved and marked DONE' : 'Saved and marked In Progress')),
              );
            },
          ),
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        rows.removeAt(index);
        carrySurface = rows.isEmpty ? SurfaceType.DT : rows.last.surface;
      });
      await _save();
}
  }

  Future<void> showRowMenu(int index) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Insert row before'),
              onTap: () => Navigator.pop(context, 'insert'),
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete row'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == 'insert') {
      await insertRowAt(index);
    } else if (choice == 'delete') {
      await deleteRowAt(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    const maxPaperWidth = 360.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chartName),
        actions: [
          IconButton(
            tooltip: isComplete ? 'Mark as In Progress' : 'Mark as Done',
            icon: Icon(isComplete ? Icons.check_circle : Icons.check_circle_outline),
            onPressed: () async {
              setState(() => isComplete = !isComplete);
              await _save();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(isComplete ? 'Saved and marked DONE' : 'Saved and marked In Progress')),
              );
            },
          ),
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.table_view),
            onPressed: () async {
              await RollchartExporter.exportCsvWeb(rows, filename: 'rollchart.csv');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloaded rollchart.csv')));
              }
            },
          ),
          IconButton(
            tooltip: 'Export PDF (2.13")',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              await RollchartExporter.exportPdfWeb(rows, filename: 'rollchart_2.13in.pdf');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloaded rollchart_2.13in.pdf')));
              }
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxPaperWidth),
          child: rows.isEmpty
              ? const Center(child: Text('No rows yet.\nTap Add Row.', textAlign: TextAlign.center))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final recNo = i + 1;

                    return InkWell(
                      onTap: () => editRow(i),
                      onLongPress: () => showRowMenu(i),
                      child: Card(
                        elevation: 1,
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Record # + ODO (your preferred layout)
                              SizedBox(
                                width: 130,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      child: Center(
                                        child: Text(
                                          '$recNo',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      formatHundredths(r.odoHundredths),
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
                                    ),
                                  ],
                                ),
                              ),

                              // Icon
                              IconSprite(
                                assetPath: sheetForKey(r.iconKey),
                                index0: indexForKey(r.iconKey),
                                size: 52,
                                padding: 1,
                              ),
                              const SizedBox(width: 10),

                              // Text block
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(surfaceText(r.surface), style: const TextStyle(fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 2),
                                    Text(rollText(r), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),
                              const Icon(Icons.more_vert, size: 18),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final recNo = rows.length + 1;
          final draft = await Navigator.push<RowDraft>(
            context,
            MaterialPageRoute(
              builder: (_) => Screen1(
                recNo: recNo,
                carrySurface: carrySurface,
                minOdoHundredthsExclusive: minOdoForNextRowExclusive(),
                maxOdoHundredthsExclusive: null,
                existingResetNames: existingResetNames(),
                initialDraft: null,
              ),
            ),
          );

          if (draft != null) {
            setState(() {
              rows.add(draft);
              carrySurface = draft.surface;
            });
            await _save();
}
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Row'),
      ),
    );
  }
}




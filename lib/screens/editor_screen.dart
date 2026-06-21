import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets/icon_sprite.dart';
import 'wizard/screen1.dart';
import '../export/exporter.dart';
import '../storage/local_store.dart';
import '../project/project_bundle_share.dart';

class RollChartEditorScreen extends StatefulWidget {
  final String chartName;
  const RollChartEditorScreen({super.key, required this.chartName});

  @override
  State<RollChartEditorScreen> createState() => _RollChartEditorScreenState();
}

class _RollChartEditorScreenState extends State<RollChartEditorScreen> {
  final ScrollController _listCtrl = ScrollController();

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
        recomputeRollchartDerived(rows);
        isComplete = loaded.isDone;
        carrySurface = rows.isEmpty ? SurfaceType.DT : rows.last.surface;
      } else {
        isComplete = false;
        carrySurface = SurfaceType.DT;
      }
      _loaded = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _save() async {
    if (!_loaded) return;
    await LocalStore.saveChart(chartName: widget.chartName, isDone: isComplete, rows: rows);
  }

  void _scrollToBottom() {
    if (!_listCtrl.hasClients) return;
    _listCtrl.jumpTo(_listCtrl.position.maxScrollExtent);
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

    return (bits.isEmpty ? '-' : bits.join(' * ')).replaceAll('[','').replaceAll(']','');
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
        final origOdo = r.odoHundredths;
        final origWasReset = r.isReset;
        rows[index] = updated;
        if (origWasReset && !updated.isReset && index + 1 < rows.length) {
          shiftOdoForward(rows, index + 1, origOdo);
        } else if (!origWasReset && updated.isReset && index + 1 < rows.length) {
          shiftOdoForward(rows, index + 1, -updated.odoHundredths);
        }
        recomputeRollchartDerived(rows);
        carrySurface = rows.isEmpty ? SurfaceType.DT : rows.last.surface;
      });
      await _save();
    }
  }

  Future<void> insertRowAt(int index) async {
    // FIX: If the row immediately before the insert point is a RESET,
    // the new row starts a fresh ODO segment from 0, so there is no
    // lower bound. Previously this passed the reset row's ODO as the
    // minimum, which incorrectly blocked any ODO entry less than that value.
    int? minExclusive;
    if (index > 0 && !rows[index - 1].isReset) {
      minExclusive = rows[index - 1].odoHundredths;
    }
    // null when previous row is a reset (new segment starts at 0)

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
        recomputeRollchartDerived(rows);
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        final wasReset = rows[index].isReset;
        final deletedOdo = rows[index].odoHundredths;
        rows.removeAt(index);
        if (wasReset && index < rows.length) {
          shiftOdoForward(rows, index, deletedOdo);
        }
        recomputeRollchartDerived(rows);
        carrySurface = rows.isEmpty ? SurfaceType.DT : rows.last.surface;
      });
      await _save();
    }
  }

  Future<void> showRowMenu(int index) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Insert row before'),
              onTap: () => Navigator.pop(sheetCtx, 'insert'),
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete row'),
              onTap: () => Navigator.pop(sheetCtx, 'delete'),
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

  Widget _buildSummaryFooter(BuildContext context) {
    final total = rows.isEmpty ? 0 : (rows.last.trueMileHundredths ?? 0);
    final legCount = rows.where((r) => r.isReset).length;
    int? firstGas;
    for (final r in rows) {
      if (r.isGas) { firstGas = r.trueMileHundredths; break; }
    }
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _footerStat('TOTAL', '${formatHundredths(total)} mi'),
          _footerStat('LEGS', '$legCount'),
          _footerStat('1ST GAS', firstGas == null ? '—' : '${formatHundredths(firstGas)} mi'),
        ],
      ),
    );
  }

  Widget _footerStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
      ],
    );
  }

  // Builds a flat display list interleaving row indices (int) with segment
  // summary items (_SegTotal) inserted after each reset row.
  List<Object> _buildDisplayList() {
    final items = <Object>[];
    int legNo = 0;
    for (int i = 0; i < rows.length; i++) {
      items.add(i);
      if (rows[i].isReset) {
        legNo++;
        items.add(_SegTotal(legNo, rows[i].odoHundredths));
      }
    }
    return items;
  }

  Widget _segSummaryRow(BuildContext context, _SegTotal s) {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'Leg ${s.legNo}  •  ${formatHundredths(s.hundredths)} mi',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const maxPaperWidth = 360.0;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
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
            tooltip: 'Export Project JSON',
            icon: const Icon(Icons.file_download),
            onPressed: () async {
              await _save();
              try {
                await ProjectBundleShare.exportProjectJson(widget.chartName);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(RollchartExporter.isWeb ? 'Downloaded project JSON' : 'Shared project JSON')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), duration: const Duration(seconds: 8)));
                }
              }
            },
          ),
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.table_view),
            onPressed: isComplete ? () async {
              await RollchartExporter.exportCsv(rows, filename: 'rollchart.csv');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(RollchartExporter.isWeb ? 'Downloaded rollchart.csv' : 'Shared rollchart.csv')));
              }
            } : null,
          ),
          IconButton(
            tooltip: 'Export PDF (2.13")',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: isComplete ? () async {
              var safeName = widget.chartName.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
              safeName = safeName.replaceAll(RegExp(r'^_+|_+$'), '');
              if (safeName.isEmpty) safeName = 'rollchart';
              await RollchartExporter.exportPdf(rows, filename: '${safeName}.pdf', chartName: widget.chartName);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(RollchartExporter.isWeb ? 'Downloaded PDF' : 'Shared PDF')));
              }
            } : null,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxPaperWidth),
          child: rows.isEmpty
              ? const Center(child: Text('No rows yet.\nTap Add Row.', textAlign: TextAlign.center))
              : Column(
                  children: [
                    Expanded(child: Builder(builder: (context) {
                  final displayList = _buildDisplayList();
                  return ListView.separated(
                    controller: _listCtrl,
                    padding: EdgeInsets.fromLTRB(10, 10, 10, 100 + bottomInset),
                    itemCount: displayList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, di) {
                      final item = displayList[di];
                      if (item is _SegTotal) {
                        return _segSummaryRow(context, item);
                      }
                      final i = item as int;
                      final r = rows[i];
                      final recNo = i + 1;

                      return InkWell(
                        onTap: isComplete ? null : () => editRow(i),
                        onLongPress: isComplete ? null : () => showRowMenu(i),
                        child: Card(
                          elevation: 1,
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Record # + ODO
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
                                IconGlyph(
                                  iconKey: r.iconKey,
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

                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: isComplete ? null : () => showRowMenu(i),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                    child: Icon(Icons.more_vert, size: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                })),
                    _buildSummaryFooter(context),
                  ],
                ),
        ),
      ),

      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomInset + MediaQuery.of(context).padding.bottom),
        child: FloatingActionButton.extended(
          onPressed: isComplete ? null : () async {
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
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Row'),
        ),
      ),
    );
  }
}

class _SegTotal {
  final int legNo;
  final int hundredths;
  const _SegTotal(this.legNo, this.hundredths);
}

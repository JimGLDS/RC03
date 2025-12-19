import 'package:flutter/material.dart';
import '../../models.dart';
import '../../widgets/icon_sprite.dart';

class Screen3 extends StatelessWidget {
  final int recNo;
  final RowDraft draft;
  final List<String> existingResetNames;

  const Screen3({
    super.key,
    required this.recNo,
    required this.draft,
    required this.existingResetNames,
  });

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

  bool resetNameIsDuplicate(String name) {
    final want = name.trim().toLowerCase();
    final used = existingResetNames.map((e) => e.trim().toLowerCase()).toSet();
    return want.isNotEmpty && used.contains(want);
  }

  String dashIfEmpty(String? s) {
    final t = (s ?? '').trim();
    return t.isEmpty ? '-' : t;
  }

  @override
  Widget build(BuildContext context) {
    final road = ('${draft.roadNo ?? ''} ${draft.roadName ?? ''}').trim();
    final resetLabel = (draft.resetLabel ?? '').trim();

    return Scaffold(
      appBar: AppBar(title: Text('Review - Row $recNo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconSprite(
                      assetPath: sheetForKey(draft.iconKey),
                      index0: indexForKey(draft.iconKey),
                      size: 72,
                      padding: 2,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('REC#: $recNo', style: const TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          Text(
                            'ODO: ${formatHundredths(draft.odoHundredths)}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 6),
                          Text('SURFACE: ${surfaceText(draft.surface)}'),
                          Text('ICON: ${draft.iconKey}'),
                          Text('TAGS: ${dashIfEmpty(draft.tags)}'),
                          Text('RIGHT NOTE: ${dashIfEmpty(draft.rightNote)}'),
                          Text('ROAD: ${road.isEmpty ? "-" : road}'),
                          Text('DESCR: ${dashIfEmpty(draft.descr)}'),
                          Text(
                            'RESET?: ${draft.isReset ? "YES" : "NO"}${draft.isReset ? " " + dashIfEmpty(resetLabel) : ""}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, null),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      if (draft.isReset) {
                        final label = (draft.resetLabel ?? '').trim();
                        if (label.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Reset name is required.')),
                          );
                          return;
                        }
                        if (resetNameIsDuplicate(label)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Reset name "$label" is already used. Choose a new name.')),
                          );
                          return;
                        }
                      }
                      Navigator.pop(context, draft);
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('SAVE'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

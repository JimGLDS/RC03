import 'package:flutter/material.dart';
import '../../models.dart';
import '../../widgets/icon_sprite.dart';
import '_clarifiers.dart';
import 'screen2l.dart';
import 'screen2r.dart';
import 'screen3.dart';
import 'decision_cells.dart';
class Screen2 extends StatefulWidget {
  final int recNo;
  final RowDraft draft;
  final List<String> existingResetNames;
  const Screen2({super.key, required this.recNo, required this.draft, required this.existingResetNames});

  @override
  State<Screen2> createState() => _Screen2State();
}

class _Screen2State extends State<Screen2> {
  late RowDraft d;
  static const sheetT = 'assets/icons/icons_t.png';

  @override
  void initState() {
    super.initState();
    d = widget.draft;
    if (!d.iconKey.startsWith('T')) d.iconKey = 'T01';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Decision — THRU (2T)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            topBar(context),
            const SizedBox(height: 12),
            Expanded(child: iconGrid(prefix: 'T', title: 'THRU', sheet: sheetT)),
            const SizedBox(height: 12),
            ClarifierButtons(draft: d),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () async {
                final result = await Navigator.push<RowDraft>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Screen3(recNo: widget.recNo, draft: d, existingResetNames: widget.existingResetNames),
                  ),
                );
                if (result != null && context.mounted) Navigator.pop(context, result);
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('NEXT'),
            ),
          ],
        ),
      ),
    );
  }

  Widget topBar(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: Text('Selected: ${d.iconKey}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
            OutlinedButton(
              onPressed: () async {
                final res = await Navigator.push<RowDraft>(
                  context,
                  MaterialPageRoute(builder: (_) => Screen2L(recNo: widget.recNo, draft: d, existingResetNames: widget.existingResetNames)),
                );
                if (res != null && context.mounted) Navigator.pop(context, res);
              },
              child: const Text('LEFT → (2L)'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () async {
                final res = await Navigator.push<RowDraft>(
                  context,
                  MaterialPageRoute(builder: (_) => Screen2R(recNo: widget.recNo, draft: d, existingResetNames: widget.existingResetNames)),
                );
                if (res != null && context.mounted) Navigator.pop(context, res);
              },
              child: const Text('RIGHT → (2R)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget iconGrid({required String prefix, required String title, required String sheet}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.15,
                ),
                itemCount: 21,
                itemBuilder: (context, i) {
                  // Decision rows (cells 9..20) are text buttons, not icon keys.
                  if (i >= 12) {
                    String label = '';
                    String value = '';
                    switch (i) {
                      case 12: label = 'DG';   value = 'DG'; break;
                      case 13: label = 'VDG';  value = 'VDG'; break;
                      case 14: label = 'OBS';  value = 'OBS'; break;
                      case 15: label = 'SM';   value = 'SM'; break;
                      case 16: label = 'ORV';  value = 'ORV'; break;
                      case 17: label = 'FS';   value = 'FS'; break;
                      case 18: label = 'XC!!'; value = 'XC'; break;
                      case 19: label = 'RR';   value = 'RR'; break;
                      case 20: label = 'NEXT'; value = 'NEXT'; break;
                      default: label = ''; value = ''; break;
                    }
                    final selectedTag = value != 'NEXT' && d.tags.split(RegExp(r'\s+')).contains(value);
                    return InkWell(
                      onTap: () {
                        if (value == 'NEXT') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Screen3(
                              recNo: widget.recNo,
                              draft: d,
                              existingResetNames: widget.existingResetNames,
                            ),
                          ),
                        );
                        return;
                      }

                        setState(() {
                          const groupA = <String>['DG', 'VDG', 'OBS'];
                          const groupB = <String>['SM', 'ORV', 'FS', 'XC', 'RR'];

                          final tokens = d.tags
                              .split(RegExp(r'\s+'))
                              .where((t) => t.trim().isNotEmpty)
                              .toList();

                          // Toggle OFF if tapped again (allows no tags).
                          if (tokens.contains(value)) {
                            tokens.removeWhere((t) => t == value);
                            d.tags = tokens.join(' ');
                            return;
                          }

                          // Exclusive across BOTH tag families (at most one tag total).
                          tokens.removeWhere((t) => groupA.contains(t) || groupB.contains(t));
                          tokens.add(value);
                          d.tags = tokens.join(' ');
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            width: selectedTag ? 4 : 1,
                            color: selectedTag ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                          ),
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                        alignment: Alignment.center,
                        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    );
                  }

                  final key = '${prefix}${(i + 1).toString().padLeft(2, '0')}';
                  final selected = d.iconKey == key;

                  return InkWell(
                    onTap: () => setState(() => d.iconKey = key),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          width: selected ? 4 : 1,
                          color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                        ),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      child: Center(child: IconSprite(assetPath: sheet, index0: i, size: 64, padding: 2)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}










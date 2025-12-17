import 'package:flutter/material.dart';
import '../../models.dart';
import '../../widgets/icon_sprite.dart';
import '_clarifiers.dart';
import 'screen2l.dart';
import 'screen2r.dart';
import 'screen3.dart';

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
                itemCount: 9,
                itemBuilder: (context, i) {
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
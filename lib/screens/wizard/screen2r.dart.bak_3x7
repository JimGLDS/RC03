import 'package:flutter/material.dart';
import '../../models.dart';
import '../../widgets/icon_sprite.dart';
import '_clarifiers.dart';
import 'screen2l.dart';
import 'screen3.dart';

class Screen2R extends StatefulWidget {
  final int recNo;
  final RowDraft draft;
  final List<String> existingResetNames;
  const Screen2R({super.key, required this.recNo, required this.draft, required this.existingResetNames});

  @override
  State<Screen2R> createState() => _Screen2RState();
}

class _Screen2RState extends State<Screen2R> {
  late RowDraft d;
  static const sheetR = 'assets/icons/icons_r.png';

  @override
  void initState() {
    super.initState();
    d = widget.draft;
    if (!d.iconKey.startsWith('R')) d.iconKey = 'R01';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Decision — RIGHT (2R)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(child: Text('Selected: ${d.iconKey}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
                    OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('← THRU')),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => Screen2L(recNo: widget.recNo, draft: d, existingResetNames: widget.existingResetNames)),
                      ),
                      child: const Text('LEFT →'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: iconGrid()),
            const SizedBox(height: 12),
            ClarifierButtons(draft: d),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () async {
                final result = await Navigator.push<RowDraft>(
                  context,
                  MaterialPageRoute(builder: (_) => Screen3(recNo: widget.recNo, draft: d, existingResetNames: widget.existingResetNames)),
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

  Widget iconGrid() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            const Text('RIGHT', style: TextStyle(fontWeight: FontWeight.w900)),
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
                  final key = 'R${(i + 1).toString().padLeft(2, '0')}';
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
                      child: Center(child: IconSprite(assetPath: sheetR, index0: i, size: 64, padding: 2)),
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
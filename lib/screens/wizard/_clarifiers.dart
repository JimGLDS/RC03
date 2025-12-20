import 'package:flutter/material.dart';
import '../../utils/upper_case_text_formatter.dart';
import '../../models.dart';

class ClarifierButtons extends StatefulWidget {
  final RowDraft draft;
  const ClarifierButtons({super.key, required this.draft});

  @override
  State<ClarifierButtons> createState() => _ClarifierButtonsState();
}

class _ClarifierButtonsState extends State<ClarifierButtons> {
  RowDraft get d => widget.draft;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: smallBtn(context, 'TAGS', d.tags.trim().isEmpty ? null : '✓', () async {
                  final v = await prompt(context, 'Tags', 'e.g. RR,ORV,DG', initial: d.tags);
                  if (v != null) setState(() => d.tags = v.trim());
                })),
                const SizedBox(width: 8),
                Expanded(child: smallBtn(context, 'DESCR', (d.descr ?? '').trim().isEmpty ? null : '✓', () async {
                  final v = await prompt(context, 'Description', 'Optional', initial: d.descr ?? '');
                  if (v != null) setState(() => d.descr = v.trim().isEmpty ? null : v.trim());
                })),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: smallBtn(context, 'RD NAME', (d.roadName ?? '').trim().isEmpty ? null : '✓', () async {
                  final v = await prompt(context, 'Road Name', 'e.g. Bliss Lake', initial: d.roadName ?? '');
                  if (v != null) setState(() => d.roadName = v.trim().isEmpty ? null : v.trim());
                })),
                const SizedBox(width: 8),
                Expanded(child: smallBtn(context, 'RD NO', (d.roadNo ?? '').trim().isEmpty ? null : '✓', () async {
                  final v = await prompt(context, 'Road Number', 'e.g. 4603', initial: d.roadNo ?? '');
                  if (v != null) setState(() => d.roadNo = v.trim().isEmpty ? null : v.trim());
                })),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: smallBtn(context, 'RIGHT NOTE', (d.rightNote ?? '').trim().isEmpty ? null : '✓', () async {
                  final v = await prompt(context, 'Right Note', 'e.g. SMTR, M72, grassy', initial: d.rightNote ?? '');
                  if (v != null) setState(() => d.rightNote = v.trim().isEmpty ? null : v.trim());
                })),
                const SizedBox(width: 8),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('RESET?', style: TextStyle(fontWeight: FontWeight.w900)),
                    value: d.isReset,
                    onChanged: (v) async {
                      setState(() => d.isReset = v);
                      if (v) {
                        final label = await prompt(context, 'Reset Name', 'e.g. A11', initial: d.resetLabel ?? '');
                        setState(() => d.resetLabel = (label ?? '').trim().isEmpty ? null : label!.trim());
                      } else {
                        setState(() => d.resetLabel = null);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget smallBtn(BuildContext context, String label, String? suffix, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          if (suffix != null) ...[
            const SizedBox(width: 8),
            Text(suffix, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900)),
          ]
        ],
      ),
    );
  }

  Future<String?> prompt(BuildContext context, String title, String hint, {String initial = ''}) async {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(inputFormatters: [UpperCaseTextFormatter()], controller: ctrl, decoration: InputDecoration(hintText: hint), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('OK')),
        ],
      ),
    );
  }
}

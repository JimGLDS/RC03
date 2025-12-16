import 'package:flutter/material.dart';
import '../../models.dart';
import 'screen2.dart';

class Screen1 extends StatefulWidget {
  final int recNo;

  // When creating: pass carrySurface; when editing: pass initialDraft.surface
  final SurfaceType carrySurface;

  // ODO rules: must be > minExclusive (if set) and < maxExclusive (if set)
  final int? minOdoHundredthsExclusive;
  final int? maxOdoHundredthsExclusive;

  final List<String> existingResetNames;

  // If editing, provide initialDraft
  final RowDraft? initialDraft;

  const Screen1({
    super.key,
    required this.recNo,
    required this.carrySurface,
    required this.minOdoHundredthsExclusive,
    required this.maxOdoHundredthsExclusive,
    required this.existingResetNames,
    this.initialDraft,
  });

  bool get isEdit => initialDraft != null;

  @override
  State<Screen1> createState() => _Screen1State();
}

class _Screen1State extends State<Screen1> {
  String digits = '';
  late SurfaceType surface;

  @override
  void initState() {
    super.initState();
    surface = widget.initialDraft?.surface ?? widget.carrySurface;
    // prefill odo digits when editing
    final d = widget.initialDraft;
    if (d != null) digits = d.odoHundredths.toString();
  }

  void tapDigit(String d) {
    setState(() {
      digits = (digits + d).replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length > 6) digits = digits.substring(digits.length - 6);
    });
  }

  void backspace() {
    setState(() {
      if (digits.isNotEmpty) digits = digits.substring(0, digits.length - 1);
    });
  }

  int get odoHundredths => digits.isEmpty ? 0 : int.parse(digits);

  bool get odoValid {
    final min = widget.minOdoHundredthsExclusive;
    final max = widget.maxOdoHundredthsExclusive;
    if (min != null && odoHundredths <= min) return false;
    if (max != null && odoHundredths >= max) return false;
    return true;
  }

  String? get odoError {
    if (digits.isEmpty) return null;
    final min = widget.minOdoHundredthsExclusive;
    final max = widget.maxOdoHundredthsExclusive;

    if (min != null && odoHundredths <= min) {
      return 'Must be greater than previous (${formatHundredths(min)})';
    }
    if (max != null && odoHundredths >= max) {
      return 'Must be less than next (${formatHundredths(max)})';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const SizedBox.shrink()),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(formatHundredths(odoHundredths),
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800)),
                          if (odoError != null) ...[
                            const SizedBox(height: 8),
                            Text(odoError!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(height: 240, child: keypad()),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
              children: [
                surfaceBtn(SurfaceType.PR),
                surfaceBtn(SurfaceType.GV),
                surfaceBtn(SurfaceType.DT),
                surfaceBtn(SurfaceType.IT),
                surfaceBtn(SurfaceType.TT),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: odoValid
                        ? () async {
                            final base = widget.initialDraft ??
                                RowDraft(
                                  odoHundredths: odoHundredths,
                                  surface: surface,
                                  iconKey: 'T01',
                                );

                            base.odoHundredths = odoHundredths;
                            base.surface = surface;

                            final result = await Navigator.push<RowDraft>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Screen2(
                                  recNo: widget.recNo,
                                  draft: base,
                                  existingResetNames: widget.existingResetNames,
                                ),
                              ),
                            );
                            if (result != null && context.mounted) Navigator.pop(context, result);
                          }
                        : null,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('NEXT'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Selected: '),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: backspace,
                    icon: const Icon(Icons.backspace_outlined),
                    label: const Text('Backspace'),
                  ),
                ),              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget surfaceBtn(SurfaceType s) {
    final selected = surface == s;
    return SizedBox(
      width: 72,
      height: 48,
      child: FilledButton(
        onPressed: () => setState(() => surface = s),
        style: FilledButton.styleFrom(
          backgroundColor: selected ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
          foregroundColor: selected ? null : Theme.of(context).colorScheme.onSurface,
        ),
        child: Text(surfaceText(s), style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }

    Widget keypad() {
    // 3x4 keypad layout; keep existing tapDigit() logic.
    final keys = <String>[
      '1','2','3',
      '4','5','6',
      '7','8','9',
      '','0','',
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 58,
          ),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final k in keys)
              k.isEmpty
                  ? const SizedBox.shrink()
                  : FilledButton(
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => tapDigit(k),
                      child: Text(
                        k,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ),
          ],
        );
      },
    );
  }
}


























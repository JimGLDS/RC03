import 'package:flutter/material.dart';
import '../../models.dart';
import 'screen2.dart';
import 'screen2l.dart';
import 'screen2r.dart';

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
      appBar: AppBar(
        leading: const BackButton(),
        title: SizedBox(
          height: 18, // reserved space so the layout never jumps
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              odoError ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ),
      ),
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
                              style: const TextStyle(
                                  fontSize: 36, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(height: 420, child: keypad()),
          ],
        ),
      ),
    );
  }

  Widget surfaceBtn(SurfaceType s) {
    final selected = surface == s;
    return FilledButton(
      style: FilledButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: selected
            ? null
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundColor:
            selected ? null : Theme.of(context).colorScheme.onSurface,
      ),
      onPressed: () => setState(() => surface = s),
      child: Text(surfaceText(s),
          style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
  Widget keypad() {
    Widget keyDigit(String d) => FilledButton(
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => tapDigit(d),
          child: Text(d, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        );

    Widget keyBackspace() => FilledButton(
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: backspace,
          child: const Icon(Icons.backspace_outlined),
        );

    Widget keyNext() => FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: odoValid
              ? () async {
                  // start with existing draft if edit, otherwise new
                  final base = widget.initialDraft ??
    RowDraft(
      odoHundredths: odoHundredths,
      surface: surface,
      iconKey: 'T01',
    );

                  base.odoHundredths = odoHundredths;
                  base.surface = surface;

                  final next = base.iconKey.startsWith('L')
    ? Screen2L(
        recNo: widget.recNo,
        draft: base,
        existingResetNames: widget.existingResetNames,
      )
    : base.iconKey.startsWith('R')
        ? Screen2R(
            recNo: widget.recNo,
            draft: base,
            existingResetNames: widget.existingResetNames,
          )
        : Screen2(
            recNo: widget.recNo,
            draft: base,
            existingResetNames: widget.existingResetNames,
          );

final result = await Navigator.push<RowDraft>(
  context,
  MaterialPageRoute(builder: (_) => next),
);
                  if (result != null && context.mounted) Navigator.pop(context, result);
                }
              : null,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('NEXT'),
        );

    final cells = <Widget>[
      // Rows 1-3 (digits)
      keyDigit('1'), keyDigit('2'), keyDigit('3'),
      keyDigit('4'), keyDigit('5'), keyDigit('6'),
      keyDigit('7'), keyDigit('8'), keyDigit('9'),

      // Row 4
      const SizedBox.shrink(), keyDigit('0'), keyBackspace(),

      // Rows 5-6 (road types + NEXT)
      surfaceBtn(SurfaceType.PR), surfaceBtn(SurfaceType.GV), surfaceBtn(SurfaceType.DT),
      surfaceBtn(SurfaceType.IT), surfaceBtn(SurfaceType.TT), keyNext(),
    ];

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 58,
      ),
      children: cells,
    );
  }
}












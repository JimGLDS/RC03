import 'package:flutter/material.dart';
import '../../models.dart';
import '../../widgets/icon_sprite.dart';


import '../../widgets/glove_keypad.dart';
import '../icon_editor_screen.dart';
class Screen3 extends StatefulWidget {
  final int recNo;
  final RowDraft draft;
  final List<String> existingResetNames;

  const Screen3({
    super.key,
    required this.recNo,
    required this.draft,
    required this.existingResetNames,
  });

  @override
  State<Screen3> createState() => _Screen3State();
}

class _Screen3State extends State<Screen3> {
  late final RowDraft d;

  late final TextEditingController roadNoCtl;
  late final TextEditingController roadNameCtl;

  @override
  void initState() {
    super.initState();
    d = widget.draft;

    roadNoCtl = TextEditingController(text: (d.roadNo ?? '').trim());
    roadNameCtl = TextEditingController(text: (d.roadName ?? '').trim());
  }

  @override
  void dispose() {
    roadNoCtl.dispose();
    roadNameCtl.dispose();
    super.dispose();
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

  String dashIfEmpty(String? s) {
    final t = (s ?? '').trim();
    return t.isEmpty ? '-' : t;
  }

  void applyRoadEdits() {
    d.roadNo = roadNoCtl.text.trim();
    d.roadName = roadNameCtl.text.trim().toUpperCase();
  }

  Future<void> editRoadNoWithKeypad() async {
    final result = await showGloveKeypad(
      context: context,
      mode: GloveKeypadMode.num,
      initialText: roadNoCtl.text,
      title: 'Road No',
    );
    if (result == null) return;
    setState(() {
      roadNoCtl.text = result.trim();
      applyRoadEdits();
    });
  }

  Future<void> editRoadNameWithKeypad() async {
    final result = await showGloveKeypad(
      context: context,
      mode: GloveKeypadMode.alpha,
      initialText: roadNameCtl.text,
      title: 'RdName/Notes',
    );
    if (result == null) return;
    setState(() {
      roadNameCtl.text = result;
      applyRoadEdits();
    });
  }


  Future<void> promptForResetName({bool turningOn = false}) async {
    final initial = (d.resetLabel ?? '').trim();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResetNameDialog(
        initial: initial,
        existingResetNames: widget.existingResetNames,
      ),
    );

    if (!mounted) return;

    if (result == null) {
      // Cancel => if we were turning on, revert the switch.
      if (turningOn) {
        setState(() {
          d.isReset = false;
          d.resetLabel = '';
        });
      }
      return;
    }

    setState(() {
      d.isReset = true;
      d.resetLabel = result.trim();
    });
  }

  void trySave() {
    applyRoadEdits();

    if (d.isReset) {
      final label = (d.resetLabel ?? '').trim();
      if (label.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reset name is required.')),
        );
        return;
      }
      // Duplicate check is already enforced in the dialog, but keep this as safety:
      final want = label.toLowerCase();
      final used = widget.existingResetNames.map((e) => e.trim().toLowerCase()).toSet();
      if (used.contains(want)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reset name "$label" is already used. Choose a new name.')),
        );
        return;
      }
    }

    Navigator.pop(context, d);
  }

  @override
  Widget build(BuildContext context) {
    final roadDisplay = ('${d.roadNo ?? ''} ${d.roadName ?? ''}').trim();
    final resetLabel = (d.resetLabel ?? '').trim();
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(title: Text('Review / Edit - Row ${widget.recNo}')),
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
                    InkWell(
                      onTap: () async {
                        final updatedKey = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => IconEditorScreen(iconKey: d.iconKey),
                          ),
                        );
                        if (!mounted) return;
                        if (updatedKey != null && updatedKey != d.iconKey) {
                          setState(() => d.iconKey = updatedKey);
                        }
                    },
                      child: IconGlyph(
                        iconKey: d.iconKey,
                        size: 72,
                        padding: 2,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('REC#: ${widget.recNo}', style: const TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          Text(
                            'ODO: ${formatHundredths(d.odoHundredths)}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 6),
                          Text('SURFACE: ${surfaceText(d.surface)}'),
                          Text('ICON: ${d.iconKey}'),
                          Text('TAGS: ${dashIfEmpty(d.tags)}'),
                          Text('ROAD: ${roadDisplay.isEmpty ? "-" : roadDisplay}'),
                          Text(
                            'RESET?: ${d.isReset ? "YES" : "NO"}${d.isReset ? " " + (resetLabel.isEmpty ? "-" : resetLabel) : ""}',
                          ),
                          Text("GAS?: ${d.isGas ? 'YES' : 'NO'}"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: SingleChildScrollView(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Road', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            SizedBox(
                              width: 110,
                              child: TextField(
                                controller: roadNoCtl,
                                readOnly: true,
                                showCursor: true,
                                enableInteractiveSelection: false,
                                onTap: () async {
                                  await editRoadNoWithKeypad();
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Road No',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) => setState(applyRoadEdits),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: roadNameCtl,
                                readOnly: true,
                                showCursor: true,
                                enableInteractiveSelection: false,
                                onTap: () async {
                                  await editRoadNameWithKeypad();
                                },
                                decoration: const InputDecoration(
                                  labelText: 'RdName/Notes',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) => setState(applyRoadEdits),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),
                        const Divider(),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            const Text('Reset?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            const Spacer(),
                            Switch(
                              value: d.isReset,
                              onChanged: (v) async {
                                if (v) {
                                  // Flip on, then require name via dialog.
                                  setState(() => d.isReset = true);
                                  await promptForResetName(turningOn: true);
                                } else {
                                  setState(() {
                                    d.isReset = false;
                                    d.resetLabel = '';
                                  });
                                }
                              },
                            ),
                          ],
                        ),


                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Gas?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            const Spacer(),
                            Switch(
                              value: d.isGas,
                              onChanged: (v) {
                                setState(() {
                                  d.isGas = v;
                                  if (v) {
                                    d.gasOdoHundredths = d.odoHundredths;
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        if (d.isReset) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Reset Name: ${resetLabel.isEmpty ? "-" : resetLabel}',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                onPressed: () async => await promptForResetName(),
                                icon: const Icon(Icons.edit),
                                label: const Text('Edit'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

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
                    onPressed: trySave,
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12 + safeBottom),
          ],
        ),
      ),
    );
  }
}

class _ResetNameDialog extends StatefulWidget {
  final String initial;
  final List<String> existingResetNames;

  const _ResetNameDialog({
    required this.initial,
    required this.existingResetNames,
  });

  @override
  State<_ResetNameDialog> createState() => _ResetNameDialogState();
}

class _ResetNameDialogState extends State<_ResetNameDialog> {
  late final TextEditingController ctl;
  String? errorText;

  @override
  void initState() {
    super.initState();
    ctl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  bool isDuplicate(String name) {
    final want = name.trim().toLowerCase();
    final used = widget.existingResetNames.map((e) => e.trim().toLowerCase()).toSet();
    return want.isNotEmpty && used.contains(want);
  }

  void validate() {
    final t = ctl.text.trim();
    if (t.isEmpty) {
      setState(() => errorText = 'Reset name is required.');
      return;
    }
    if (isDuplicate(t)) {
      setState(() => errorText = 'That reset name is already used.');
      return;
    }
    setState(() => errorText = null);
  }


  Future<void> openKeypad() async {
    final result = await showGloveKeypad(
      context: context,
      mode: GloveKeypadMode.alpha,
      initialText: ctl.text,
      title: 'Reset Name',
    );
    if (result == null) return;
    setState(() {
      ctl.text = result;
    });
    validate();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Name'),
      content: TextField(
        controller: ctl,
        readOnly: true,
        showCursor: true,
        enableInteractiveSelection: false,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Enter reset name',
          errorText: errorText,
        ),
        onTap: () async => await openKeypad(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            validate();
            if (errorText != null) return;
            Navigator.pop(context, ctl.text.trim());
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}





import 'package:flutter/material.dart';
import 'screen2.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 36,
        titleSpacing: 0,
        title: const Text('Decision - RIGHT (2R)', style: TextStyle(fontSize: 14)),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + MediaQuery.of(context).padding.bottom),
        child: Column(
          children: [
            const SizedBox.shrink(),
            const SizedBox(height: 6),
            Expanded(child: iconGrid()),
          ],
        ),
      ),
    );
  }

  Widget iconGrid() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            const Text('RIGHT', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),

            // TOP: 3Ãƒâ€”3 ICONS (square, no scroll)
            LayoutBuilder(
              builder: (context, c) {
                const spacing = 10.0;
                final tile = (c.maxWidth - (spacing * 2)) / 3.0;
                final h = (tile * 3) + (spacing * 2);
                return SizedBox(
                  height: h,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      childAspectRatio: 1.0,
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
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outlineVariant,
                            ),
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                          child: Center(child: IconSprite(assetPath: sheetR, index0: i, size: 64, padding: 2)),
                        ),
                      );
                    },
                  ),
                );
              },
            ),

            const SizedBox(height: 6),

            // BOTTOM: LEFT/THRU/RIGHT + TAGS + NEXT
            Expanded(
              child: LayoutBuilder(
                builder: (context, bc) {
                  const spacing = 10.0;
                  final tileW = (bc.maxWidth - (spacing * 2)) / 3.0;
                  final tileH = (bc.maxHeight - (spacing * 3)) / 4.0;
                  final ar = (tileW / tileH).clamp(1.25, 10.0);

                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      childAspectRatio: ar,
                    ),
                itemCount: 12,
                itemBuilder: (context, j) {
                  final i = j + 9;

                  if (i >= 9 && i <= 11) {
                    String label = '';
                    final which = i - 9;
                    if (which == 0) label = 'LEFT';
                    if (which == 1) label = 'THRU';
                    if (which == 2) label = 'RIGHT';

                    final isSelected = label == 'RIGHT';
                    return InkWell(
                      onTap: () async {
                        if (isSelected) return;

                        if (label == 'LEFT') {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Screen2L(
                                recNo: widget.recNo,
                                draft: d,
                                existingResetNames: widget.existingResetNames,
                              ),
                            ),
                          );
                          if (result != null && context.mounted) Navigator.pop(context, result);
                          return;
                        }

                        if (label == 'THRU') {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Screen2(
                                recNo: widget.recNo,
                                draft: d,
                                existingResetNames: widget.existingResetNames,
                              ),
                            ),
                          );
                          if (result != null && context.mounted) Navigator.pop(context, result);
                          return;
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            width: isSelected ? 4 : 1,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                          ),
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                        alignment: Alignment.center,
                        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    );
                  }

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
                    onTap: () async {
                      if (value == 'NEXT') {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Screen3(
                              recNo: widget.recNo,
                              draft: d,
                              existingResetNames: widget.existingResetNames,
                            ),
                          ),
                        );
                        if (result != null && context.mounted) Navigator.pop(context, result);
                        return;
                      }

                      setState(() {
                        const groupA = <String>['DG', 'VDG', 'OBS'];
                        const groupB = <String>['SM', 'ORV', 'FS', 'XC', 'RR'];

                        final tokens = d.tags
                            .split(RegExp(r'\s+'))
                            .where((t) => t.trim().isNotEmpty)
                            .toList();

                        if (tokens.contains(value)) {
                          tokens.removeWhere((t) => t == value);
                          d.tags = tokens.join(' ');
                          return;
                        }

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
                          color: selectedTag
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      alignment: Alignment.center,
                      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  );
                },
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

import 'package:flutter/material.dart';
import '../../models.dart';
import 'screen2.dart';
import 'screen2l.dart';
import 'screen2r.dart';
import 'screen3.dart';

enum DecisionVariant { thru, left, right }

FilledButton _tile(String label, VoidCallback? onPressed, {double fontSize = 18}) {
  return FilledButton(
    style: FilledButton.styleFrom(
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    onPressed: onPressed,
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900),
    ),
  );
}

Widget decisionCell({
  required BuildContext context,
  required int i,
  required int recNo,
  required RowDraft d,
  required List<String> existingResetNames,
  required DecisionVariant variant,
}) {
  // i  9-11 : variant row
  // i 12-14 : DG | VDG | OBS
  // i 15-17 : SM | ORV | FS
  // i 18-20 : XC!! | RR | NEXT
  switch (i) {
    // Row 4 (variant-specific)
    case 9:
      if (variant == DecisionVariant.left) return _tile('+', null);
      if (variant == DecisionVariant.right) {
        return _tile('LEFT', () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => Screen2L(recNo: recNo, draft: d, existingResetNames: existingResetNames)),
          );
        });
      }
      // THRU (center)
      return _tile('LEFT', () async {
        final res = await Navigator.push<RowDraft>(
          context,
          MaterialPageRoute(builder: (_) => Screen2L(recNo: recNo, draft: d, existingResetNames: existingResetNames)),
        );
        if (res != null && context.mounted) Navigator.pop(context, res);
      });

    case 10:
      // All variants have THRU here
      return _tile('THRU', () {
        if (variant == DecisionVariant.thru) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => Screen2(recNo: recNo, draft: d, existingResetNames: existingResetNames)),
          );
        }
      });

    case 11:
      if (variant == DecisionVariant.right) return _tile('+', null);
      if (variant == DecisionVariant.left) {
        return _tile('RT', () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => Screen2R(recNo: recNo, draft: d, existingResetNames: existingResetNames)),
          );
        });
      }
      // THRU (center)
      return _tile('RT', () async {
        final res = await Navigator.push<RowDraft>(
          context,
          MaterialPageRoute(builder: (_) => Screen2R(recNo: recNo, draft: d, existingResetNames: existingResetNames)),
        );
        if (res != null && context.mounted) Navigator.pop(context, res);
      });

    // Row 5 (shared)
    case 12: return _tile('DG', null);
    case 13: return _tile('VDG', null, fontSize: 16);
    case 14: return _tile('OBS', null, fontSize: 16);

    // Row 6 (shared)
    case 15: return _tile('SM', null);
    case 16: return _tile('ORV', null);
    case 17: return _tile('FS', null);

    // Row 7 (shared)
    case 18: return _tile('XC!!', null, fontSize: 16);
    case 19: return _tile('RR', null);
    case 20:
      return FilledButton(
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () async {
          final result = await Navigator.push<RowDraft>(
            context,
            MaterialPageRoute(builder: (_) => Screen3(recNo: recNo, draft: d, existingResetNames: existingResetNames)),
          );
          if (result != null && context.mounted) Navigator.pop(context, result);
        },
        child: const Icon(Icons.play_arrow),
      );
  }

  return const SizedBox.shrink();
}

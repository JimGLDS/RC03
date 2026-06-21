enum SurfaceType { PR, GV, DT, IT, TT }

String surfaceText(SurfaceType s) {
  switch (s) {
    case SurfaceType.PR:
      return 'PR';
    case SurfaceType.GV:
      return 'GV';
    case SurfaceType.DT:
      return 'DT';
    case SurfaceType.IT:
      return '1T';
    case SurfaceType.TT:
      return '2T';
  }
}

String formatHundredths(int v) {
  final neg = v < 0;
  final a = v.abs();
  final whole = a ~/ 100;
  final frac = (a % 100).toString().padLeft(2, '0');
  return '${neg ? '-' : ''}$whole.$frac';
}

class RowDraft {
  int odoHundredths;
  int segHundredthsFromPrev; // distance from previous record to this record (hundredths)
  SurfaceType surface;
  String iconKey;
  String decisionKey;

  String tags;
  String? rightNote;
  String? roadName;
  String? roadNo;
  String? descr;

  bool isReset;
  String? resetLabel;

  bool isGas;
  int? gasOdoHundredths;

  // Derived / computed (do not edit directly)
  int? trueMileHundredths;     // absolute mile from rollchart start (hundredths)
  int? remainingHundredths;    // total - true mile (hundredths)
  int? nextGasHundredths;      // distance to NEXT gas (hundredths), strictly after current

  RowDraft({
    required this.odoHundredths,
    this.segHundredthsFromPrev = 0,
    required this.surface,
    required this.iconKey,
    this.decisionKey = '',
    this.tags = '',
    this.rightNote,
    this.roadName,
    this.roadNo,
    this.descr,
    this.isReset = false,
    this.resetLabel,
    this.isGas = false,
    this.gasOdoHundredths,
  });

  /// COPY CONSTRUCTOR (for edit workflows)
  RowDraft.clone(RowDraft other)
      : odoHundredths = other.odoHundredths,
        segHundredthsFromPrev = other.segHundredthsFromPrev,
        surface = other.surface,
        iconKey = other.iconKey,
        decisionKey = other.decisionKey,
        tags = other.tags,
        rightNote = other.rightNote,
        roadName = other.roadName,
        roadNo = other.roadNo,
        descr = other.descr,
        isReset = other.isReset,
        resetLabel = other.resetLabel,
        isGas = other.isGas,
        gasOdoHundredths = other.gasOdoHundredths,
        trueMileHundredths = other.trueMileHundredths,
        remainingHundredths = other.remainingHundredths,
        nextGasHundredths = other.nextGasHundredths;
}

///////////////////////////////////////////////////////////////////////////////
/// Rebuilds segHundredthsFromPrev for every row based on neighboring odoHundredths.
/// IMPORTANT: This must only be called when odoHundredths values are already
/// correct. Never call this before fixing ODOs after a reset boundary change —
/// it will overwrite the segment distances that are needed to reconstruct ODOs.
void rebuildSegFromPrev(List<RowDraft> rows) {
  if (rows.isEmpty) return;
  rows[0].segHundredthsFromPrev = 0;
  for (int i = 1; i < rows.length; i++) {
    final d = rows[i].odoHundredths - rows[i - 1].odoHundredths;
    rows[i].segHundredthsFromPrev = d < 0 ? 0 : d;
  }
}

// ROLLCHART DERIVED METRICS
//
// This recomputes "true mile", "remaining miles", and "distance to NEXT gas"
// based on segment-ODO + RESET boundaries.
//
// Definitions:
// - Each row's odoHundredths is miles since last reset (segment odo).
// - A RESET row closes a segment; its odoHundredths is the segment length.
// - A GAS stop is always also a RESET (isGas => isReset).
// - "Next gas" is strictly AFTER the current point (gasTrue > hereTrue).
//
// Call this AFTER any edit/insert/delete/reorder, and BEFORE any CSV/PDF export.
///////////////////////////////////////////////////////////////////////////////

class RollchartDerivedSummary {
  final int totalHundredths;
  final int? nextGasFromStartHundredths;

  const RollchartDerivedSummary({
    required this.totalHundredths,
    required this.nextGasFromStartHundredths,
  });
}

RollchartDerivedSummary recomputeRollchartDerived(List<RowDraft> rows) {
  // 0) Keep persisted segment lengths in sync with current odo values.
  rebuildSegFromPrev(rows);

  // 1) Enforce Gas => Reset (your rule).
  for (final r in rows) {
    if (r.isGas && !r.isReset) {
      r.isReset = true;
    }
  }

  // 2) Compute true miles (absolute miles from rollchart start).
  final trueMiles = List<int>.filled(rows.length, 0);
  int base = 0;
  for (int i = 0; i < rows.length; i++) {
    final r = rows[i];
    final t = base + r.odoHundredths;
    trueMiles[i] = t;
    try { r.trueMileHundredths = t; } catch (_) {}
    if (r.isReset) {
      base += r.odoHundredths;
    }
  }

  final total = rows.isEmpty ? 0 : trueMiles[rows.length - 1];

  // 3) Gather gas true-miles in order.
  final gasTrueMiles = <int>[];
  for (int i = 0; i < rows.length; i++) {
    if (rows[i].isGas) {
      gasTrueMiles.add(trueMiles[i]);
    }
  }

  int? nextGasAfter(int x) {
    for (final g in gasTrueMiles) {
      if (g > x) return g;
    }
    return null;
  }

  // 4) Compute remaining + next-gas distance for each row.
  for (int i = 0; i < rows.length; i++) {
    final here = trueMiles[i];
    final remaining = total - here;
    try { rows[i].remainingHundredths = remaining; } catch (_) {}

    final nextGas = nextGasAfter(here);
    final distToNextGas = (nextGas == null) ? null : (nextGas - here);
    try { rows[i].nextGasHundredths = distToNextGas; } catch (_) {}
  }

  // 5) Start-of-rollchart "next gas" from mile 0.00.
  final startNextGas = nextGasAfter(0);
  final startDist = (startNextGas == null) ? null : (startNextGas - 0);

  return RollchartDerivedSummary(
    totalHundredths: total,
    nextGasFromStartHundredths: startDist,
  );
}

// RC41_ODO_RECOMPUTE_HELPERS_V2
int findPrevResetIndex(List<RowDraft> rows, int fromIndex) {
  var i = fromIndex;
  if (rows.isEmpty) return -1;
  if (i >= rows.length) i = rows.length - 1;
  for (; i >= 0; i--) {
    if (rows[i].isReset) return i;
  }
  return -1;
}

void recomputeOdoFromAnchorUpToAndIncludingNextReset(List<RowDraft> rows, int anchorIndex) {
  if (rows.isEmpty) return;
  if (anchorIndex < 0) anchorIndex = 0;
  if (anchorIndex >= rows.length) return;

  rows[anchorIndex].odoHundredths = 0;

  var odo = 0;
  for (int j = anchorIndex + 1; j < rows.length; j++) {
    odo += rows[j].segHundredthsFromPrev;
    rows[j].odoHundredths = odo;
    if (rows[j].isReset) break;
  }
}

void recomputeOdoAfterResetBoundaryChangeV2(List<RowDraft> rows, int changedIndex) {
  if (rows.isEmpty) return;
  if (changedIndex < 0) changedIndex = 0;
  if (changedIndex >= rows.length) return;

  final prevReset = findPrevResetIndex(rows, changedIndex - 1);
  final anchor = prevReset >= 0 ? prevReset : 0;
  recomputeOdoFromAnchorUpToAndIncludingNextReset(rows, anchor);
}

///////////////////////////////////////////////////////////////////////////////
/// RC42 — Safe full recompute after a reset boundary change.
///
/// The problem with calling recomputeRollchartDerived directly after a reset
/// toggle or delete is that it starts with rebuildSegFromPrev, which overwrites
/// segHundredthsFromPrev using the CURRENT (still-wrong) odoHundredths values.
/// This destroys the stored segment distances before they can be used to
/// reconstruct correct ODOs.
///
/// This function fixes that by doing things in the correct order:
///   1. Fix ODO values first (uses segHundredthsFromPrev before it is clobbered)
///   2. THEN run the full derived recompute (which rebuilds segHundredthsFromPrev
///      from the now-correct ODO values, then computes trueMile, remaining, etc.)
///
/// Call this instead of recomputeRollchartDerived whenever a reset boundary
/// has changed — i.e. after deleting a reset row, or toggling isReset on/off.
///////////////////////////////////////////////////////////////////////////////
RollchartDerivedSummary recomputeAfterResetBoundaryChange(List<RowDraft> rows, int changedIndex) {
  // Step 1: Fix ODO values using stored segment distances BEFORE they get
  // overwritten by rebuildSegFromPrev inside recomputeRollchartDerived.
  recomputeOdoAfterResetBoundaryChangeV2(rows, changedIndex);

  // Step 2: Now that ODOs are correct, run the full derived recompute.
  return recomputeRollchartDerived(rows);
}

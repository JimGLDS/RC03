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
  RowDraft({
    required this.odoHundredths,
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
        gasOdoHundredths = other.gasOdoHundredths;
}

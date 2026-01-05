import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../storage/local_store.dart';
import '../widgets/icon_sprite.dart';

class _Stroke {
  final List<Offset> points;
  final bool isEraser;
  _Stroke(this.points, this.isEraser);
}

class IconEditorScreen extends StatefulWidget {
  final String iconKey;
  const IconEditorScreen({super.key, required this.iconKey});

  @override
  State<IconEditorScreen> createState() => _IconEditorScreenState();
}

class _IconEditorScreenState extends State<IconEditorScreen> {
  bool? isEraser;
  final List<_Stroke> _strokes = [];
  List<Offset>? _active;
  final GlobalKey _captureKey = GlobalKey();


  void _undoLast() {
    setState(() {
      if (_active != null && _active!.isNotEmpty) {
        _active = null;
        return;
      }
      if (_strokes.isNotEmpty) {
        _strokes.removeLast();
      }
    });
  }

  Widget _tileButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool selected = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected ? cs.primary : cs.surfaceVariant;
    final fg = selected ? cs.onPrimary : cs.onSurfaceVariant;

    return SizedBox(
      height: 52,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, color: fg, size: 28),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSave(String iconKey) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save icon?'),
        content: const Text('Save your edits and return to the previous screen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (ok == true) {
      final bytes = await _capturePngBytes();
      if (bytes == null || bytes.isEmpty) return;

      final upper = iconKey.toUpperCase();
      final outKey = upper.startsWith('C') ? upper : await LocalStore.nextCustomIconKey();
      await LocalStore.saveCustomIconPng(outKey, bytes);

      if (!mounted) return;
      Navigator.pop(context, outKey);
    }
  }
  void _startStroke(Offset p) {
    setState(() => _active = [p]);
  }

  void _addPoint(Offset p) {
    final pts = _active;
    if (pts == null) return;
    setState(() => pts.add(p));
  }

  void _endStroke() {
    final pts = _active;
    if (pts == null || pts.length < 2) return;
    setState(() {
      _strokes.add(_Stroke(List<Offset>.from(pts), isEraser == true));
      _active = null;
    });
  }

  double _strokeWidth(double canvasSize) {
    final base = (canvasSize * 0.030).clamp(2.0, 8.0);
    if (isEraser == true) return (base + 2.0).clamp(2.0, 10.0);
    return base;
  }

  String sheetForKey(String iconKey) {
    if (iconKey.startsWith('T')) return 'assets/icons/icons_t.png';
    if (iconKey.startsWith('L')) return 'assets/icons/icons_l.png';
    return 'assets/icons/icons_r.png';
  }

  int indexForKey(String iconKey) {
    final trail = (iconKey.length >= 2) ? iconKey.substring(iconKey.length - 2) : '';
    final num = int.tryParse(trail) ?? 1;
    return (num - 1).clamp(0, 8);
  }
  Widget _baseIconWidget(String iconKey, double size) {
    final k = iconKey.toUpperCase();
    if (k.startsWith('C')) {
      return FutureBuilder<Uint8List?>(
        future: LocalStore.loadCustomIconPng(k),
        builder: (context, snap) {
          final bytes = snap.data;
          if (bytes != null && bytes.isNotEmpty) {
            return Image.memory(bytes, fit: BoxFit.contain, filterQuality: FilterQuality.high);
          }
          return IconSprite(
            assetPath: sheetForKey(iconKey),
            index0: indexForKey(iconKey),
            size: size,
            padding: 6,
          );
        },
      );
    }
    return IconSprite(
      assetPath: sheetForKey(iconKey),
      index0: indexForKey(iconKey),
      size: size,
      padding: 6,
    );
  }

  Future<Uint8List?> _capturePngBytes() async {
    final ctx = _captureKey.currentContext;
    if (ctx == null) return null;
    final ro = ctx.findRenderObject();
    if (ro is! RenderRepaintBoundary) return null;

    // 1) Capture the composed icon (base + strokes) as PNG bytes
    final uiImg = await ro.toImage(pixelRatio: 1.0);
    final bd = await uiImg.toByteData(format: ui.ImageByteFormat.png);
    if (bd == null) return null;
    var bytes = bd.buffer.asUint8List();

    // 2) If there are eraser strokes, convert the erased pixels to TRUE transparency
    final hasEraser = _strokes.any((s) => s.isEraser) || (isEraser == true && (_active?.isNotEmpty ?? false));
    if (!hasEraser) return bytes;

    final decoded = img.decodePng(bytes);
    if (decoded == null) return bytes;

    final w = decoded.width;
    final h = decoded.height;

    // Match the stroke width used by the painter at pixelRatio 1.0
    final strokeW = _strokeWidth(w.toDouble());
    final radius = math.max(1.0, strokeW / 2.0);

    void clearCircle(int cx, int cy, double r) {
      final rInt = r.ceil();
      final r2 = r * r;
      final x0 = math.max(0, cx - rInt);
      final x1 = math.min(w - 1, cx + rInt);
      final y0 = math.max(0, cy - rInt);
      final y1 = math.min(h - 1, cy + rInt);
      for (var y = y0; y <= y1; y++) {
        final dy = (y - cy).toDouble();
        for (var x = x0; x <= x1; x++) {
          final dx = (x - cx).toDouble();
          if (dx * dx + dy * dy <= r2) {
            decoded.setPixelRgba(x, y, 0, 0, 0, 0);
          }
        }
      }
    }

    void clearLine(Offset a, Offset b) {
      final dx = b.dx - a.dx;
      final dy = b.dy - a.dy;
      final steps = math.max(1, (dx.abs() + dy.abs()).round());
      for (var i = 0; i <= steps; i++) {
        final t = i / steps;
        final x = (a.dx + dx * t).round();
        final y = (a.dy + dy * t).round();
        if (x >= 0 && x < w && y >= 0 && y < h) {
          clearCircle(x, y, radius);
        }
      }
    }

    // Apply all committed eraser strokes
    for (final st in _strokes.where((s) => s.isEraser)) {
      final pts = st.points;
      for (var i = 1; i < pts.length; i++) {
        clearLine(pts[i - 1], pts[i]);
      }
    }

    // Apply the active stroke if it's an eraser and currently drawing
    final a = _active;
    if (isEraser == true && a != null && a.length >= 2) {
      for (var i = 1; i < a.length; i++) {
        clearLine(a[i - 1], a[i]);
      }
    }

    return Uint8List.fromList(img.encodePng(decoded));
  }


  @override
  Widget build(BuildContext context) {
    final iconKey = widget.iconKey;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40,
        titleSpacing: 12,
        title: const Text('Edit Icon'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.maxWidth;
              return Column(
                children: [
                  Flexible(fit: FlexFit.loose,
                      child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                      child: ClipRect(
                        child: RepaintBoundary(key: _captureKey, child: Stack(
                          children: [
                              Positioned.fill(
                              child: IgnorePointer(
                                  ignoring: true,
                                child: Container(
                                  decoration: BoxDecoration(
                                  border: Border.all(width: 1),
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Center(
                                child: _baseIconWidget(iconKey, size),
                              ),
                            ),
                            Positioned.fill(
                              child: GestureDetector(
                                onPanStart: (d) {
                                  if (isEraser == null) return;
                                  _startStroke(d.localPosition);
                                },
                                onPanUpdate: (d) {
                                  if (isEraser == null) return;
                                  _addPoint(d.localPosition);
                                },
                                onPanEnd: (_) {
                                  if (isEraser == null) return;
                                  _endStroke();
                                },
                                child: CustomPaint(
                                  painter: _StrokePainter(
                                    strokes: _strokes,
                                    active: _active,
                                    strokeWidth: _strokeWidth(size),
                                    activeIsEraser: isEraser == true,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        ),
                       ),
                    ),
                   ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _tileButton(
                          icon: Icons.undo,
                          tooltip: 'Undo',
                          onPressed: (_active != null && _active!.isNotEmpty) || _strokes.isNotEmpty
                              ? _undoLast
                              : null,
                          selected: false,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _tileButton(
                          icon: Icons.auto_fix_off,
                          tooltip: 'Eraser',
                          onPressed: () => setState(() => isEraser = true),
                          selected: isEraser == true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _tileButton(
                          icon: Icons.edit,
                          tooltip: 'Pencil',
                          onPressed: () => setState(() => isEraser = false),
                          selected: isEraser == false,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => _confirmSave(iconKey),
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
                ),
              ],
           );
          },
          ),
        ),
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  final List<_Stroke> strokes;
  final List<Offset>? active;
  final double strokeWidth;
  final bool activeIsEraser;
  _StrokePainter({
    required this.strokes,
    required this.active,
    required this.strokeWidth,
    required this.activeIsEraser,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      _draw(canvas, s.points, s.isEraser, preview: false);
    }
    final a = active;
    if (a != null && a.length >= 2) {
      _draw(canvas, a, activeIsEraser, preview: true);
    }
  }

  void _draw(Canvas canvas, List<Offset> pts, bool eraser, {required bool preview}) {
    if (pts.length < 2) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth;

    if (eraser) {
      if (preview) {
        paint.blendMode = BlendMode.srcOver;
        paint.color = Colors.white;
      } else {
        paint.blendMode = BlendMode.srcOver;
        paint.color = Colors.white;
      }
    } else {
      paint.blendMode = BlendMode.srcOver;
      paint.color = Colors.black;
    }

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.active != active ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.activeIsEraser != activeIsEraser;
  }
}

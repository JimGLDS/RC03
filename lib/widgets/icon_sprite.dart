import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../storage/local_store.dart';
import '../project/project_icon_pack.dart';

/// Crops one cell from a 3x3 sprite sheet (row-major index 0..8)
/// by drawing the full image at 3x size behind a clipped square and
/// translating it so the requested cell lands inside the box.
class IconSprite extends StatelessWidget {
  final String assetPath;   // e.g. assets/icons/icons_t.png
  final int index0;         // 0..8 (row-major)
  final double size;        // displayed size
  final double padding;     // optional padding

  const IconSprite({
    super.key,
    required this.assetPath,
    required this.index0,
    this.size = 56,
    this.padding = 2,
  });

  @override
  Widget build(BuildContext context) {
    final row = index0 ~/ 3; // 0..2
    final col = index0 % 3;  // 0..2

    return SizedBox(
      width: size,
      height: size,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            return ClipRect(
              child: Stack(
                children: [
                  Positioned(
                    left: -col * w,
                    top: -row * h,
                    width: w * 3,
                    height: h * 3,
                    child: Image.asset(
                      assetPath,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class IconGlyph extends StatelessWidget {
  final String iconKey;
  final double size;
  final double padding;

  const IconGlyph({
    super.key,
    required this.iconKey,
    this.size = 56,
    this.padding = 2,
  });

  String _sheetForKey(String k) {
    if (k.startsWith('T')) return 'assets/icons/icons_t.png';
    if (k.startsWith('L')) return 'assets/icons/icons_l.png';
    return 'assets/icons/icons_r.png';
  }

  int _indexForKey(String k) {
    final trail = (k.length >= 2) ? k.substring(k.length - 2) : '';
    final num = int.tryParse(trail) ?? 1;
    return (num - 1).clamp(0, 8);
  }
  @override
  Widget build(BuildContext context) {
    final k = iconKey.toUpperCase();

    if (ProjectIconPack.isActive) {
      return FutureBuilder<Uint8List>(
        future: ProjectIconPack.iconPngBytes(k),
        builder: (context, snap) {
          final bytes = snap.data;
          if (bytes != null && bytes.isNotEmpty) {
            return SizedBox(
              width: size,
              height: size,
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Image.memory(bytes, fit: BoxFit.contain, filterQuality: FilterQuality.high),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      );
    }

    if (k.startsWith('C')) {
      return FutureBuilder<Uint8List?>(
        future: LocalStore.loadCustomIconPng(k),
        builder: (context, snap) {
          final bytes = snap.data;
          if (bytes != null && bytes.isNotEmpty) {
            return SizedBox(
              width: size,
              height: size,
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Image.memory(bytes, fit: BoxFit.contain, filterQuality: FilterQuality.high),
              ),
            );
          }

          return IconSprite(
            assetPath: _sheetForKey(k),
            index0: _indexForKey(k),
            size: size,
            padding: padding,
          );
        },
      );
    }

    return IconSprite(
      assetPath: _sheetForKey(k),
      index0: _indexForKey(k),
      size: size,
      padding: padding,
    );
  }
  }

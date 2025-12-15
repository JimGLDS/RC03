import 'package:flutter/material.dart';

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
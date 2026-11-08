import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// How a block is drawn. Clearing the whole board moves to the next look.
enum SkinShape { tile, gem, bubble, leaf }

class Skin {
  final String name;
  final SkinShape shape;
  final List<Color> colors; // 6 block colours
  final Color board;
  final Color empty;
  const Skin(this.name, this.shape, this.colors, this.board, this.empty);
}

const skins = <Skin>[
  Skin(
    'Bahçe',
    SkinShape.tile,
    [Color(0xFF7CC47A), Color(0xFFE07B4F), Color(0xFFF4B740), Color(0xFFA98BE0), Color(0xFFEC7F9A), Color(0xFF5EAEE0)],
    Color(0xFFE6DCC6),
    Color(0xFFD9CDB3),
  ),
  Skin(
    'Kristal',
    SkinShape.gem,
    [Color(0xFF2FBF9F), Color(0xFFE0457B), Color(0xFFF2C230), Color(0xFF8A5CF5), Color(0xFF3D8BF2), Color(0xFFF2762E)],
    Color(0xFFE3E0EE),
    Color(0xFFD2CEE2),
  ),
  Skin(
    'Okyanus',
    SkinShape.bubble,
    [Color(0xFF3FC1E0), Color(0xFF2E86DE), Color(0xFF48D1A8), Color(0xFF7F8CFF), Color(0xFFFF8FA3), Color(0xFFFFC857)],
    Color(0xFFD8EEF2),
    Color(0xFFC3E1E8),
  ),
  Skin(
    'Sonbahar',
    SkinShape.leaf,
    [Color(0xFFC8553D), Color(0xFFE8A33D), Color(0xFF8C9F3A), Color(0xFFB0413E), Color(0xFFD9822B), Color(0xFF6B8F47)],
    Color(0xFFEFE2CC),
    Color(0xFFE0CFB2),
  ),
];

Color shade(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}

/// The outline a block of this look fills.
Path skinPath(SkinShape shape, Rect cell) {
  final w = cell.width;
  switch (shape) {
    case SkinShape.tile:
      return Path()..addRRect(RRect.fromRectAndRadius(cell, Radius.circular(w * 0.22)));
    case SkinShape.gem:
      return Path()..addRRect(RRect.fromRectAndRadius(cell, Radius.circular(w * 0.08)));
    case SkinShape.bubble:
      return Path()..addOval(cell.deflate(w * 0.02));
    case SkinShape.leaf:
      final big = Radius.circular(w * 0.5), small = Radius.circular(w * 0.08);
      return Path()
        ..addRRect(RRect.fromRectAndCorners(cell, topLeft: big, bottomRight: big, topRight: small, bottomLeft: small));
  }
}

/// Patterns the player can pick for the blocks.
enum BlockPattern { none, stripes, dots, checks, waves, stars }

const patternNames = <BlockPattern, String>{
  BlockPattern.none: 'Düz',
  BlockPattern.stripes: 'Çizgili',
  BlockPattern.dots: 'Puantiyeli',
  BlockPattern.checks: 'Kareli',
  BlockPattern.waves: 'Dalgalı',
  BlockPattern.stars: 'Yıldızlı',
};

/// The part of [photo] that belongs to board cell (row, col), so that all
/// blocks on the board together show one picture.
Rect photoPiece(ui.Image photo, int row, int col, int gridSize) {
  final iw = photo.width.toDouble(), ih = photo.height.toDouble();
  final side = min(iw, ih);
  final step = side / gridSize;
  return Rect.fromLTWH((iw - side) / 2 + col * step, (ih - side) / 2 + row * step, step, step);
}

/// Draws one block in the given look and colour. With [photo] and
/// [photoSrc] it shows that piece of the player's photo instead.
void paintSkinBlock(
  Canvas canvas,
  Rect rect,
  int colorIndex,
  Skin skin, {
  double opacity = 1,
  ui.Image? photo,
  Rect? photoSrc,
  BlockPattern pattern = BlockPattern.none,
}) {
  final color = skin.colors[colorIndex % skin.colors.length];
  final cell = rect.deflate(rect.width * 0.05);
  if (photo != null && photoSrc != null) {
    _photoBlock(canvas, rect, skin.shape, photo, photoSrc, opacity);
    return;
  }
  switch (skin.shape) {
    case SkinShape.tile:
      _tile(canvas, cell, color, opacity);
    case SkinShape.gem:
      _gem(canvas, cell, color, opacity);
    case SkinShape.bubble:
      _bubble(canvas, cell, color, opacity);
    case SkinShape.leaf:
      _leaf(canvas, cell, color, opacity);
  }
  if (pattern != BlockPattern.none) {
    canvas.save();
    canvas.clipPath(skinPath(skin.shape, cell));
    paintPattern(canvas, cell, pattern, shade(color, 0.28).withValues(alpha: 0.55 * opacity));
    canvas.restore();
  }
}

/// Draws [pattern] over [r] in [ink]; the caller clips to the block.
void paintPattern(Canvas canvas, Rect r, BlockPattern pattern, Color ink) {
  final w = r.width;
  final fill = Paint()..color = ink;
  final line = Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = max(1, w * 0.07);
  switch (pattern) {
    case BlockPattern.none:
      return;
    case BlockPattern.stripes:
      for (var k = -3; k <= 4; k++) {
        final x = r.left + k * w * 0.26;
        canvas.drawLine(Offset(x, r.bottom), Offset(x + w, r.top), line);
      }
    case BlockPattern.dots:
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          final shift = j.isOdd ? w * 0.14 : 0.0;
          canvas.drawCircle(Offset(r.left + w * (0.2 + 0.3 * i) + shift, r.top + w * (0.2 + 0.3 * j)), w * 0.07, fill);
        }
      }
    case BlockPattern.checks:
      final n = 4, s = w / n;
      for (var i = 0; i < n; i++) {
        for (var j = 0; j < n; j++) {
          if ((i + j).isEven) canvas.drawRect(Rect.fromLTWH(r.left + i * s, r.top + j * s, s, s), fill);
        }
      }
    case BlockPattern.waves:
      for (var k = 0; k < 3; k++) {
        final y0 = r.top + w * (0.25 + 0.27 * k);
        final path = Path()..moveTo(r.left, y0);
        for (var x = 0.0; x <= w; x += w / 16) {
          path.lineTo(r.left + x, y0 + sin(x / w * 2 * pi * 1.5) * w * 0.07);
        }
        canvas.drawPath(path, line..strokeWidth = max(1, w * 0.06));
      }
    case BlockPattern.stars:
      for (final (fx, fy, fs) in const [(0.3, 0.32, 0.15), (0.7, 0.62, 0.13), (0.72, 0.24, 0.08), (0.28, 0.76, 0.08)]) {
        final c = Offset(r.left + w * fx, r.top + w * fy);
        final path = Path();
        for (var i = 0; i < 10; i++) {
          final rad = i.isEven ? w * fs : w * fs * 0.45;
          final ang = -pi / 2 + i * pi / 5;
          final pt = c + Offset(cos(ang), sin(ang)) * rad;
          i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(path..close(), fill);
      }
  }
}

void _sparkle(Canvas canvas, Offset p, double s, double a) {
  final star = Path()
    ..moveTo(p.dx, p.dy - s)
    ..quadraticBezierTo(p.dx, p.dy, p.dx + s, p.dy)
    ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + s)
    ..quadraticBezierTo(p.dx, p.dy, p.dx - s, p.dy)
    ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - s)
    ..close();
  canvas.drawPath(star, Paint()..color = Colors.white.withValues(alpha: 0.85 * a));
}

void _shine(Canvas canvas, Rect face, double a, {double radiusFactor = 0.5}) {
  final shine = Rect.fromLTWH(
    face.left + face.width * 0.14,
    face.top + face.height * 0.09,
    face.width * 0.72,
    face.height * 0.30,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(shine, Radius.circular(shine.height * radiusFactor)),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.45 * a),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(shine),
  );
}

/// Garden: raised glossy tile.
void _tile(Canvas canvas, Rect cell, Color color, double a) {
  final radius = Radius.circular(cell.width * 0.22);
  final depth = cell.height * 0.09;
  canvas.drawRRect(RRect.fromRectAndRadius(cell, radius), Paint()..color = shade(color, -0.18).withValues(alpha: a));
  final face = Rect.fromLTRB(cell.left, cell.top, cell.right, cell.bottom - depth);
  final faceR = RRect.fromRectAndRadius(face, radius);
  canvas.drawRRect(
    faceR,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          shade(color, 0.10).withValues(alpha: a),
          color.withValues(alpha: a),
        ],
      ).createShader(face),
  );
  canvas.drawRRect(
    faceR.deflate(0.5),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, cell.width * 0.03)
      ..color = shade(color, 0.16).withValues(alpha: 0.6 * a),
  );
  _shine(canvas, face, a);
  _sparkle(canvas, Offset(face.left + face.width * 0.26, face.top + face.height * 0.26), face.width * 0.07, a);
}

/// Crystal: a cut gem with four bevelled facets around a bright table.
void _gem(Canvas canvas, Rect cell, Color color, double a) {
  final inset = cell.width * 0.22;
  final inner = cell.deflate(inset);
  Paint p(double l) => Paint()..color = shade(color, l).withValues(alpha: a);
  Path quad(Offset a1, Offset a2, Offset a3, Offset a4) => Path()
    ..moveTo(a1.dx, a1.dy)
    ..lineTo(a2.dx, a2.dy)
    ..lineTo(a3.dx, a3.dy)
    ..lineTo(a4.dx, a4.dy)
    ..close();
  canvas.save();
  canvas.clipRRect(RRect.fromRectAndRadius(cell, Radius.circular(cell.width * 0.08)));
  canvas.drawPath(quad(cell.topLeft, cell.topRight, inner.topRight, inner.topLeft), p(0.20));
  canvas.drawPath(quad(cell.topLeft, inner.topLeft, inner.bottomLeft, cell.bottomLeft), p(0.08));
  canvas.drawPath(quad(cell.topRight, cell.bottomRight, inner.bottomRight, inner.topRight), p(-0.10));
  canvas.drawPath(quad(cell.bottomLeft, inner.bottomLeft, inner.bottomRight, cell.bottomRight), p(-0.20));
  canvas.drawRect(
    inner,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          shade(color, 0.14).withValues(alpha: a),
          color.withValues(alpha: a),
        ],
      ).createShader(inner),
  );
  canvas.restore();
  // Facet edges.
  final edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(0.8, cell.width * 0.02)
    ..color = Colors.white.withValues(alpha: 0.35 * a);
  canvas.drawRect(inner, edge);
  canvas.drawLine(cell.topLeft, inner.topLeft, edge);
  canvas.drawLine(cell.topRight, inner.topRight, edge);
  canvas.drawLine(cell.bottomLeft, inner.bottomLeft, edge);
  canvas.drawLine(cell.bottomRight, inner.bottomRight, edge);
  _sparkle(canvas, Offset(inner.left + inner.width * 0.3, inner.top + inner.height * 0.3), cell.width * 0.09, a);
}

/// Ocean: a round bubble with a bright rim and highlight.
void _bubble(Canvas canvas, Rect cell, Color color, double a) {
  final oval = cell.deflate(cell.width * 0.02);
  canvas.drawOval(
    oval,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 0.95,
        colors: [
          shade(color, 0.22).withValues(alpha: a),
          color.withValues(alpha: a),
          shade(color, -0.16).withValues(alpha: a),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(oval),
  );
  canvas.drawOval(
    oval.deflate(0.6),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, cell.width * 0.04)
      ..color = shade(color, 0.25).withValues(alpha: 0.7 * a),
  );
  final hl = Rect.fromLTWH(
    oval.left + oval.width * 0.2,
    oval.top + oval.height * 0.12,
    oval.width * 0.38,
    oval.height * 0.22,
  );
  canvas.drawOval(hl, Paint()..color = Colors.white.withValues(alpha: 0.6 * a));
  canvas.drawCircle(
    Offset(oval.left + oval.width * 0.7, oval.top + oval.height * 0.72),
    oval.width * 0.06,
    Paint()..color = Colors.white.withValues(alpha: 0.35 * a),
  );
}

/// Autumn: a leaf-shaped block with a central vein.
void _leaf(Canvas canvas, Rect cell, Color color, double a) {
  final path = skinPath(SkinShape.leaf, cell);
  canvas.drawPath(
    path,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          shade(color, 0.14).withValues(alpha: a),
          shade(color, -0.10).withValues(alpha: a),
        ],
      ).createShader(cell),
  );
  final vein = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = max(1, cell.width * 0.045)
    ..color = shade(color, -0.22).withValues(alpha: 0.7 * a);
  final from = Offset(cell.left + cell.width * 0.2, cell.bottom - cell.height * 0.2);
  final to = Offset(cell.right - cell.width * 0.2, cell.top + cell.height * 0.2);
  canvas.drawLine(from, to, vein);
  final mid = Offset.lerp(from, to, 0.5)!;
  final side = vein..strokeWidth = max(1, cell.width * 0.03);
  canvas.drawLine(mid, mid + Offset(-cell.width * 0.16, -cell.height * 0.02), side);
  canvas.drawLine(mid, mid + Offset(cell.width * 0.02, cell.height * 0.16), side);
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, cell.width * 0.03)
      ..color = shade(color, 0.2).withValues(alpha: 0.6 * a),
  );
  _sparkle(canvas, Offset(cell.left + cell.width * 0.3, cell.top + cell.height * 0.3), cell.width * 0.07, a);
}

/// One piece of the player's photo, nearly edge to edge so neighbouring
/// blocks join into one picture, with a soft bevel to keep the block feel.
void _photoBlock(Canvas canvas, Rect rect, SkinShape shape, ui.Image photo, Rect src, double a) {
  final cell = rect.deflate(rect.width * 0.015);
  final path = skinPath(shape == SkinShape.bubble ? SkinShape.bubble : SkinShape.gem, cell);
  canvas.save();
  canvas.clipPath(path);
  canvas.drawImageRect(
    photo,
    src,
    rect,
    Paint()
      ..color = Colors.white.withValues(alpha: a)
      ..filterQuality = FilterQuality.medium,
  );
  // Light top-left edge and dark bottom-right edge.
  final edge = cell.width * 0.08;
  canvas.drawRect(
    Rect.fromLTWH(cell.left, cell.top, cell.width, edge),
    Paint()..color = Colors.white.withValues(alpha: 0.22 * a),
  );
  canvas.drawRect(
    Rect.fromLTWH(cell.left, cell.top, edge, cell.height),
    Paint()..color = Colors.white.withValues(alpha: 0.14 * a),
  );
  canvas.drawRect(
    Rect.fromLTWH(cell.left, cell.bottom - edge, cell.width, edge),
    Paint()..color = Colors.black.withValues(alpha: 0.18 * a),
  );
  canvas.drawRect(
    Rect.fromLTWH(cell.right - edge, cell.top, edge, cell.height),
    Paint()..color = Colors.black.withValues(alpha: 0.12 * a),
  );
  canvas.restore();
}

/// Empty hole on the board, matching the look.
void paintSkinEmpty(Canvas canvas, Rect rect, Skin skin) {
  final cell = rect.deflate(rect.width * 0.06);
  final path = skinPath(skin.shape, cell);
  canvas.drawPath(path, Paint()..color = skin.empty);
  canvas.save();
  canvas.clipPath(path);
  final band = Rect.fromLTWH(cell.left, cell.top, cell.width, cell.height * 0.22);
  canvas.drawRect(
    band,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.black.withValues(alpha: 0.10), Colors.black.withValues(alpha: 0.0)],
      ).createShader(band),
  );
  canvas.restore();
}

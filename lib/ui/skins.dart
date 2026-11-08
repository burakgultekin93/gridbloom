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

/// Draws one block in the given look and colour, optionally with the
/// player's own photo inside it.
void paintSkinBlock(Canvas canvas, Rect rect, int colorIndex, Skin skin, {double opacity = 1, ui.Image? photo}) {
  final color = skin.colors[colorIndex % skin.colors.length];
  final cell = rect.deflate(rect.width * 0.05);
  if (photo != null) {
    _photoBlock(canvas, cell, color, skin.shape, photo, opacity);
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

/// The player's photo inside the block's outline, with a coloured frame.
void _photoBlock(Canvas canvas, Rect cell, Color color, SkinShape shape, ui.Image photo, double a) {
  final path = skinPath(shape, cell);
  canvas.save();
  canvas.clipPath(path);
  final iw = photo.width.toDouble(), ih = photo.height.toDouble();
  final side = min(iw, ih);
  final src = Rect.fromLTWH((iw - side) / 2, (ih - side) / 2, side, side);
  canvas.drawImageRect(
    photo,
    src,
    cell,
    Paint()
      ..color = Colors.white.withValues(alpha: a)
      ..filterQuality = FilterQuality.medium,
  );
  canvas.drawRect(cell, Paint()..color = color.withValues(alpha: 0.22 * a));
  canvas.restore();
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(2, cell.width * 0.09)
      ..color = color.withValues(alpha: a),
  );
  _shine(canvas, cell.deflate(cell.width * 0.06), a * 0.7);
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

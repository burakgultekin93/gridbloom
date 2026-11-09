import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// How a block is drawn. Clearing the whole board moves to the next look.
enum SkinShape { neon, ice, magma, gem }

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
    'Neon',
    SkinShape.neon,
    [Color(0xFF3DF2C4), Color(0xFFFF4D8D), Color(0xFFFFC93D), Color(0xFFA66BFF), Color(0xFF3DB8FF), Color(0xFFFF7A2E)],
    Color(0xFF111729),
    Color(0xFF1A2238),
  ),
  Skin(
    'Buz',
    SkinShape.ice,
    [Color(0xFF8FE3FF), Color(0xFF5FB4FF), Color(0xFFB7A8FF), Color(0xFF7FF0DA), Color(0xFFD8F4FF), Color(0xFF6E8CFF)],
    Color(0xFF0F2236),
    Color(0xFF173149),
  ),
  Skin(
    'Magma',
    SkinShape.magma,
    [Color(0xFFFF5A1F), Color(0xFFFFB02E), Color(0xFFFF2E4D), Color(0xFFFFE066), Color(0xFFFF7F50), Color(0xFFE83CFF)],
    Color(0xFF170F0E),
    Color(0xFF241917),
  ),
  Skin(
    'Kristal',
    SkinShape.gem,
    [Color(0xFF2FBF9F), Color(0xFFE0457B), Color(0xFFF2C230), Color(0xFF8A5CF5), Color(0xFF3D8BF2), Color(0xFFF2762E)],
    Color(0xFF151230),
    Color(0xFF211C44),
  ),
];

Color shade(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}

/// A square with its corners cut off at [cut] of the width.
Path chamfer(Rect r, double cut) {
  final k = r.width * cut;
  return Path()
    ..moveTo(r.left + k, r.top)
    ..lineTo(r.right - k, r.top)
    ..lineTo(r.right, r.top + k)
    ..lineTo(r.right, r.bottom - k)
    ..lineTo(r.right - k, r.bottom)
    ..lineTo(r.left + k, r.bottom)
    ..lineTo(r.left, r.bottom - k)
    ..lineTo(r.left, r.top + k)
    ..close();
}

/// The outline a block of this look fills.
Path skinPath(SkinShape shape, Rect cell) {
  final w = cell.width;
  switch (shape) {
    case SkinShape.neon:
      return chamfer(cell, 0.2);
    case SkinShape.ice:
      return Path()..addRRect(RRect.fromRectAndRadius(cell, Radius.circular(w * 0.06)));
    case SkinShape.magma:
      return chamfer(cell, 0.1);
    case SkinShape.gem:
      return Path()..addRRect(RRect.fromRectAndRadius(cell, Radius.circular(w * 0.08)));
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
    case SkinShape.neon:
      _neon(canvas, cell, color, opacity);
    case SkinShape.ice:
      _ice(canvas, cell, color, opacity, colorIndex);
    case SkinShape.magma:
      _magma(canvas, cell, color, opacity, colorIndex);
    case SkinShape.gem:
      _gem(canvas, cell, color, opacity);
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

/// Neon: a chamfered block of dark tinted glass with a glowing rim, a
/// split facet and a bright core.
void _neon(Canvas canvas, Rect cell, Color color, double a) {
  final w = cell.width;
  final outline = chamfer(cell, 0.2);
  // Outer glow.
  canvas.drawPath(
    outline,
    Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.12)
      ..color = color.withValues(alpha: 0.45 * a),
  );
  // Dark glass body, lighter toward the top left.
  canvas.drawPath(
    outline,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(color, const Color(0xFF0A0E1C), 0.45)!.withValues(alpha: a),
          Color.lerp(color, const Color(0xFF0A0E1C), 0.78)!.withValues(alpha: a),
        ],
      ).createShader(cell),
  );
  // Upper-left facet catches the light.
  canvas.save();
  canvas.clipPath(outline);
  canvas.drawPath(
    Path()
      ..moveTo(cell.left, cell.top)
      ..lineTo(cell.right, cell.top)
      ..lineTo(cell.left, cell.bottom)
      ..close(),
    Paint()..color = Colors.white.withValues(alpha: 0.07 * a),
  );
  canvas.restore();
  // Inner line and neon rim.
  canvas.drawPath(
    chamfer(cell.deflate(w * 0.17), 0.2),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, w * 0.025)
      ..color = color.withValues(alpha: 0.35 * a),
  );
  canvas.drawPath(
    chamfer(cell.deflate(w * 0.035), 0.2),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.2, w * 0.07)
      ..color = shade(color, 0.08).withValues(alpha: a),
  );
  canvas.drawPath(
    chamfer(cell.deflate(w * 0.035), 0.2),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.6, w * 0.02)
      ..color = Colors.white.withValues(alpha: 0.55 * a),
  );
  // Glowing core.
  final c = cell.center;
  canvas.drawCircle(
    c,
    w * 0.16,
    Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.08)
      ..color = color.withValues(alpha: 0.9 * a),
  );
  final d = w * 0.08;
  canvas.drawPath(
    Path()
      ..moveTo(c.dx, c.dy - d)
      ..lineTo(c.dx + d, c.dy)
      ..lineTo(c.dx, c.dy + d)
      ..lineTo(c.dx - d, c.dy)
      ..close(),
    Paint()..color = Colors.white.withValues(alpha: 0.9 * a),
  );
}

/// Ice: a frosted, see-through cube with a bright edge and frozen cracks.
void _ice(Canvas canvas, Rect cell, Color color, double a, int seed) {
  final w = cell.width;
  final r = RRect.fromRectAndRadius(cell, Radius.circular(w * 0.06));
  canvas.drawRRect(
    r,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(color, Colors.white, 0.55)!.withValues(alpha: 0.95 * a),
          color.withValues(alpha: 0.75 * a),
          Color.lerp(color, const Color(0xFF0B2A4A), 0.45)!.withValues(alpha: 0.85 * a),
        ],
        stops: const [0, 0.5, 1],
      ).createShader(cell),
  );
  canvas.save();
  canvas.clipRRect(r);
  // Frost band across the top and a dark inner bottom edge.
  canvas.drawRect(
    Rect.fromLTWH(cell.left, cell.top, w, w * 0.18),
    Paint()..color = Colors.white.withValues(alpha: 0.35 * a),
  );
  canvas.drawRect(
    Rect.fromLTWH(cell.left, cell.bottom - w * 0.1, w, w * 0.1),
    Paint()..color = const Color(0xFF0B2A4A).withValues(alpha: 0.25 * a),
  );
  // Cracks, different for each colour so the board does not look tiled.
  final crack = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(0.7, w * 0.022)
    ..color = Colors.white.withValues(alpha: 0.75 * a);
  final rnd = Random(seed * 7 + 3);
  final start = Offset(cell.left + w * (0.2 + rnd.nextDouble() * 0.6), cell.top + w * (0.25 + rnd.nextDouble() * 0.5));
  for (var k = 0; k < 3; k++) {
    final ang = k * 2 * pi / 3 + rnd.nextDouble();
    final path = Path()..moveTo(start.dx, start.dy);
    var p = start;
    for (var s = 0; s < 3; s++) {
      p += Offset(cos(ang + (rnd.nextDouble() - 0.5)), sin(ang + (rnd.nextDouble() - 0.5))) * w * 0.17;
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, crack);
  }
  canvas.restore();
  canvas.drawRRect(
    r.deflate(0.5),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, w * 0.045)
      ..color = Colors.white.withValues(alpha: 0.7 * a),
  );
}

/// Magma: a dark basalt block split by glowing lava veins.
void _magma(Canvas canvas, Rect cell, Color color, double a, int seed) {
  final w = cell.width;
  final outline = chamfer(cell, 0.1);
  canvas.drawPath(
    outline,
    Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.1)
      ..color = color.withValues(alpha: 0.35 * a),
  );
  canvas.drawPath(
    outline,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(const Color(0xFF3A2C2A), color, 0.12)!.withValues(alpha: a),
          const Color(0xFF1A1110).withValues(alpha: a),
        ],
      ).createShader(cell),
  );
  canvas.save();
  canvas.clipPath(outline);
  final rnd = Random(seed * 13 + 5);
  final hub = Offset(cell.left + w * (0.35 + rnd.nextDouble() * 0.3), cell.top + w * (0.35 + rnd.nextDouble() * 0.3));
  final veins = Path();
  for (var k = 0; k < 4; k++) {
    final ang = k * pi / 2 + rnd.nextDouble() * 0.9;
    var p = hub;
    veins.moveTo(p.dx, p.dy);
    for (var s = 0; s < 3; s++) {
      p += Offset(cos(ang + (rnd.nextDouble() - 0.5) * 0.9), sin(ang + (rnd.nextDouble() - 0.5) * 0.9)) * w * 0.22;
      veins.lineTo(p.dx, p.dy);
    }
  }
  canvas.drawPath(
    veins,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.16
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.06)
      ..color = color.withValues(alpha: 0.55 * a),
  );
  canvas.drawPath(
    veins,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = max(1, w * 0.06)
      ..color = color.withValues(alpha: a),
  );
  canvas.drawPath(
    veins,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = max(0.6, w * 0.02)
      ..color = const Color(0xFFFFF1B0).withValues(alpha: 0.9 * a),
  );
  canvas.drawCircle(hub, w * 0.07, Paint()..color = const Color(0xFFFFF1B0).withValues(alpha: a));
  canvas.restore();
  // Rough rock edge: light top, dark bottom.
  canvas.drawPath(
    chamfer(cell.deflate(0.5), 0.1),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, w * 0.04)
      ..color = const Color(0xFF6A5450).withValues(alpha: 0.8 * a),
  );
}

/// One piece of the player's photo, nearly edge to edge so neighbouring
/// blocks join into one picture, with a soft bevel to keep the block feel.
void _photoBlock(Canvas canvas, Rect rect, SkinShape shape, ui.Image photo, Rect src, double a) {
  final cell = rect.deflate(rect.width * 0.015);
  final path = skinPath(SkinShape.gem, cell);
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

/// Empty hole on the board, matching the look: a dark recess with a faint rim.
void paintSkinEmpty(Canvas canvas, Rect rect, Skin skin) {
  final cell = rect.deflate(rect.width * 0.06);
  final path = skinPath(skin.shape, cell);
  canvas.drawPath(path, Paint()..color = skin.empty);
  canvas.save();
  canvas.clipPath(path);
  final band = Rect.fromLTWH(cell.left, cell.top, cell.width, cell.height * 0.25);
  canvas.drawRect(
    band,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.black.withValues(alpha: 0.35), Colors.black.withValues(alpha: 0.0)],
      ).createShader(band),
  );
  canvas.restore();
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.6, cell.width * 0.02)
      ..color = Colors.white.withValues(alpha: 0.05),
  );
}

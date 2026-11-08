import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/pieces.dart';
import 'palette.dart';
import 'skins.dart';

Color _shade(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}

/// Draws one block as a raised, glossy garden tile: a darker base edge,
/// a face that brightens toward the top, a soft shine and a small sparkle.
void paintBlock(Canvas canvas, Rect rect, Color color, {double opacity = 1}) {
  final a = opacity;
  final cell = rect.deflate(rect.width * 0.05);
  final radius = Radius.circular(cell.width * 0.22);
  final depth = cell.height * 0.09;

  // Base edge, slightly lower, gives the tile thickness.
  canvas.drawRRect(RRect.fromRectAndRadius(cell, radius), Paint()..color = _shade(color, -0.18).withValues(alpha: a));

  // Face.
  final face = Rect.fromLTRB(cell.left, cell.top, cell.right, cell.bottom - depth);
  final faceR = RRect.fromRectAndRadius(face, radius);
  canvas.drawRRect(
    faceR,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _shade(color, 0.10).withValues(alpha: a),
          color.withValues(alpha: a),
        ],
      ).createShader(face),
  );
  canvas.drawRRect(
    faceR.deflate(0.5),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, cell.width * 0.03)
      ..color = _shade(color, 0.16).withValues(alpha: 0.6 * a),
  );

  // Shine across the upper part of the face.
  final shine = Rect.fromLTWH(
    face.left + face.width * 0.14,
    face.top + face.height * 0.09,
    face.width * 0.72,
    face.height * 0.30,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(shine, Radius.circular(shine.height / 2)),
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

  // Small sparkle in the upper left.
  final sp = Offset(face.left + face.width * 0.26, face.top + face.height * 0.26);
  final s = face.width * 0.07;
  final star = Path()
    ..moveTo(sp.dx, sp.dy - s)
    ..quadraticBezierTo(sp.dx, sp.dy, sp.dx + s, sp.dy)
    ..quadraticBezierTo(sp.dx, sp.dy, sp.dx, sp.dy + s)
    ..quadraticBezierTo(sp.dx, sp.dy, sp.dx - s, sp.dy)
    ..quadraticBezierTo(sp.dx, sp.dy, sp.dx, sp.dy - s)
    ..close();
  canvas.drawPath(star, Paint()..color = Colors.white.withValues(alpha: 0.85 * a));
}

/// A flower that opens and fades where a block was cleared.
class Bloom {
  final int r, c, color;
  final DateTime start;

  /// Streak heat when the flower opened: hot streaks give burning flowers.
  final double heat;
  Bloom(this.r, this.c, this.color, this.start, {this.heat = 0});
  static const duration = Duration(milliseconds: 700);
}

/// A short flash of light on cells a piece was just placed on.
class PlaceFlash {
  final List<(int, int)> cells;
  final DateTime start;
  PlaceFlash(this.cells, this.start);
  static const duration = Duration(milliseconds: 480);
}

/// A beam of light running along a row or column that cleared.
class LineBeam {
  final bool isRow;
  final int index;
  final DateTime start;
  LineBeam(this.isRow, this.index, this.start);
  static const duration = Duration(milliseconds: 520);
}

/// Light effects shown on the board.
class BoardFx {
  final List<PlaceFlash> flashes = [];
  final List<LineBeam> beams = [];
  DateTime? glint; // a diagonal shine across all blocks
  static const glintDuration = Duration(milliseconds: 750);

  bool get busy => flashes.isNotEmpty || beams.isNotEmpty || glint != null;

  void prune(DateTime now) {
    flashes.removeWhere((f) => now.difference(f.start) > PlaceFlash.duration);
    beams.removeWhere((b) => now.difference(b.start) > LineBeam.duration);
    if (glint != null && now.difference(glint!) > glintDuration) glint = null;
  }

  void clear() {
    flashes.clear();
    beams.clear();
    glint = null;
  }
}

class BoardPainter extends CustomPainter {
  final GameState game;
  final PieceShape? ghost;
  final int ghostRow, ghostCol, ghostColor;
  final List<int> clearRows, clearCols;
  final List<Bloom> blooms;
  final DateTime now;
  final Skin skin;
  final ui.Image? photo;
  final BoardFx fx;
  final BlockPattern pattern;

  BoardPainter({
    required this.game,
    required this.ghost,
    required this.ghostRow,
    required this.ghostCol,
    required this.ghostColor,
    required this.clearRows,
    required this.clearCols,
    required this.blooms,
    required this.now,
    required this.skin,
    required this.photo,
    required this.fx,
    required this.pattern,
  });

  double _t(DateTime start, Duration d) => now.difference(start).inMicroseconds / d.inMicroseconds;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / boardSize;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cell * 0.35)),
      Paint()..color = skin.board,
    );
    Rect rectAt(int r, int c) => Rect.fromLTWH(c * cell, r * cell, cell, cell);

    final ghostCells = <int>{};
    if (ghost != null) {
      for (final g in ghost!.cells) {
        ghostCells.add((ghostRow + g.r) * boardSize + ghostCol + g.c);
      }
    }

    final blockArea = Path();
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        final rect = rectAt(r, c);
        final v = game.board[r][c];
        final inClearLine = clearRows.contains(r) || clearCols.contains(c);
        if (v >= 0) {
          // Blocks in a line about to clear take the dragged piece's colour.
          paintSkinBlock(
            canvas,
            rect,
            inClearLine ? ghostColor : v,
            skin,
            photo: photo,
            photoSrc: photo == null ? null : photoPiece(photo!, r, c, boardSize),
            pattern: pattern,
          );
          blockArea.addRect(rect);
        } else if (ghostCells.contains(r * boardSize + c)) {
          paintSkinBlock(
            canvas,
            rect,
            ghostColor,
            skin,
            opacity: 0.55,
            photo: photo,
            photoSrc: photo == null ? null : photoPiece(photo!, r, c, boardSize),
            pattern: pattern,
          );
        } else {
          paintSkinEmpty(canvas, rect, skin);
          // A faint preview of the board picture waiting to be revealed.
          if (photo != null) {
            final hole = rect.deflate(cell * 0.06);
            canvas.save();
            canvas.clipPath(skinPath(skin.shape, hole));
            canvas.drawImageRect(
              photo!,
              photoPiece(photo!, r, c, boardSize),
              rect,
              Paint()
                ..color = Colors.white.withValues(alpha: 0.3)
                ..filterQuality = FilterQuality.medium,
            );
            canvas.restore();
          }
        }
        if (inClearLine && (v >= 0 || ghostCells.contains(r * boardSize + c))) {
          canvas.drawPath(
            skinPath(skin.shape, rect.deflate(cell * 0.05)),
            Paint()..color = Colors.white.withValues(alpha: 0.25),
          );
        }
      }
    }

    // Diagonal shine sweeping across every block after a placement.
    final glint = fx.glint;
    if (glint != null) {
      final t = _t(glint, BoardFx.glintDuration);
      if (t >= 0 && t <= 1) {
        canvas.save();
        canvas.clipPath(blockArea);
        final span = size.width * 2;
        final x = -size.width * 0.6 + t * (span + size.width * 0.6);
        final band = Rect.fromLTWH(x - size.width * 0.25, 0, size.width * 0.5, size.height);
        canvas.translate(size.width / 2, size.height / 2);
        canvas.rotate(-pi / 6);
        canvas.translate(-size.width / 2, -size.height / 2);
        canvas.drawRect(
          band.inflate(size.height),
          Paint()
            ..shader = LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.35),
                Colors.white.withValues(alpha: 0),
              ],
            ).createShader(band),
        );
        canvas.restore();
      }
    }

    // Flash on freshly placed cells.
    for (final f in fx.flashes) {
      final t = _t(f.start, PlaceFlash.duration);
      if (t < 0 || t > 1) continue;
      final k = (1 - t) * (1 - t);
      for (final (r, c) in f.cells) {
        final rect = rectAt(r, c);
        canvas.drawPath(
          skinPath(skin.shape, rect.deflate(cell * 0.05)),
          Paint()..color = Colors.white.withValues(alpha: 0.55 * k),
        );
        canvas.drawPath(
          skinPath(skin.shape, rect.inflate(cell * 0.08 * t)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.08
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.12)
            ..color = Colors.white.withValues(alpha: 0.7 * k),
        );
      }
    }

    // Light beams along cleared lines.
    for (final b in fx.beams) {
      final t = _t(b.start, LineBeam.duration);
      if (t < 0 || t > 1) continue;
      final line = b.isRow
          ? Rect.fromLTWH(0, b.index * cell, size.width, cell)
          : Rect.fromLTWH(b.index * cell, 0, cell, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(line.deflate(cell * 0.04), Radius.circular(cell * 0.3)),
        Paint()
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.25)
          ..color = const Color(0xFFFFF3C4).withValues(alpha: 0.65 * (1 - t)),
      );
      final pos = t * 1.4 - 0.2;
      final grad = b.isRow
          ? LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.95),
                Colors.white.withValues(alpha: 0),
              ],
              stops: [(pos - 0.15).clamp(0.0, 1.0), pos.clamp(0.0, 1.0), (pos + 0.15).clamp(0.0, 1.0)],
            )
          : LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.95),
                Colors.white.withValues(alpha: 0),
              ],
              stops: [(pos - 0.15).clamp(0.0, 1.0), pos.clamp(0.0, 1.0), (pos + 0.15).clamp(0.0, 1.0)],
            );
      canvas.drawRect(line.deflate(cell * 0.18), Paint()..shader = grad.createShader(line));
    }

    for (final b in blooms) {
      final t = now.difference(b.start).inMilliseconds / Bloom.duration.inMilliseconds;
      if (t < 0 || t > 1) continue;
      _paintBloom(canvas, rectAt(b.r, b.c), b.color, t, b.heat);
    }
  }

  void _paintBloom(Canvas canvas, Rect rect, int color, double t, double heat) {
    final center = rect.center;
    final grow = Curves.easeOutBack.transform(min(1, t * 1.6));
    final fade = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
    final fire = ((heat - 0.25) / 0.5).clamp(0.0, 1.0);
    final w = rect.width;

    if (fire > 0) {
      // Flames rise from the flower: glow, then three flickering tongues.
      canvas.drawCircle(
        center,
        w * 0.55 * grow,
        Paint()
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.25)
          ..color = const Color(0xFFFF7A1A).withValues(alpha: 0.6 * fire * fade),
      );
      final lift = -w * 0.35 * t;
      for (final (dx, hScale, col) in const [
        (-0.18, 0.75, Color(0xFFD7301F)),
        (0.18, 0.8, Color(0xFFD7301F)),
        (0.0, 1.0, Color(0xFFF47B20)),
        (0.0, 0.62, Color(0xFFFFD34D)),
      ]) {
        final flick = 0.85 + 0.15 * sin(t * 40 + dx * 30);
        final h = w * 0.95 * hScale * fire * grow * flick;
        final half = w * 0.2 * hScale * grow;
        final base = center + Offset(dx * w, w * 0.15 + lift);
        final tip = base + Offset(sin(t * 25 + dx * 9) * w * 0.05, -h);
        final flame = Path()
          ..moveTo(base.dx - half, base.dy)
          ..quadraticBezierTo(base.dx - half * 1.1, base.dy - h * 0.55, tip.dx, tip.dy)
          ..quadraticBezierTo(base.dx + half * 1.1, base.dy - h * 0.55, base.dx + half, base.dy)
          ..arcToPoint(Offset(base.dx - half, base.dy), radius: Radius.circular(half), clockwise: true)
          ..close();
        canvas.drawPath(flame, Paint()..color = col.withValues(alpha: 0.9 * fade));
      }
    }

    final petalR = w * 0.2 * grow;
    final dist = w * 0.22 * grow;
    final petalColor = Color.lerp(Palette.petals[color], const Color(0xFFFFB347), fire)!;
    final petal = Paint()..color = petalColor.withValues(alpha: fade);
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * pi / 5 - pi / 2 + t * 0.8;
      canvas.drawCircle(center + Offset(cos(a), sin(a)) * dist, petalR, petal);
    }
    final heart = Color.lerp(Palette.blocks[2], const Color(0xFFD7301F), fire)!;
    canvas.drawCircle(center, petalR * 0.8, Paint()..color = heart.withValues(alpha: fade));
    if (fire > 0) {
      canvas.drawCircle(center, petalR * 0.4, Paint()..color = const Color(0xFFFFF1A8).withValues(alpha: fade * fire));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Draws a piece at a given cell size, used in the tray and while dragging.
class PiecePainter extends CustomPainter {
  final PieceShape shape;
  final int color;
  final double cell;
  final double opacity;
  final Skin skin;
  final BlockPattern pattern;
  PiecePainter(
    this.shape,
    this.color,
    this.cell, {
    this.opacity = 1,
    required this.skin,
    this.pattern = BlockPattern.none,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ox = (size.width - shape.cols * cell) / 2;
    final oy = (size.height - shape.rows * cell) / 2;
    for (final c in shape.cells) {
      paintSkinBlock(
        canvas,
        Rect.fromLTWH(ox + c.c * cell, oy + c.r * cell, cell, cell),
        color,
        skin,
        opacity: opacity,
        pattern: pattern,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PiecePainter old) =>
      old.shape != shape ||
      old.color != color ||
      old.cell != cell ||
      old.opacity != opacity ||
      old.skin != skin ||
      old.pattern != pattern;
}

/// The logo flower used on the home screen.
class LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 3;
    final colors = [0, 2, 4, 3, 1, 5, 4, 0, 2];
    for (var i = 0; i < 9; i++) {
      if (i == 4) continue;
      paintBlock(canvas, Rect.fromLTWH((i % 3) * cell, (i ~/ 3) * cell, cell, cell), Palette.blocks[colors[i]]);
    }
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * pi / 5 - pi / 2;
      canvas.drawCircle(center + Offset(cos(a), sin(a)) * cell * 0.28, cell * 0.22, Paint()..color = Palette.petals[1]);
    }
    canvas.drawCircle(center, cell * 0.18, Paint()..color = Palette.blocks[2]);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

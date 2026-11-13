import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/pieces.dart';
import 'bursts.dart';
import 'heat_fx.dart';
import 'skins.dart';

/// A cleared block that freezes and shatters (cold streak) or burns and
/// breaks apart (hot streak).
class Bloom {
  final int r, c, color;
  final DateTime start;

  /// Streak heat when the block cleared: hot streaks burn, cold ones freeze.
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
  final List<Burst> bursts = [];

  // Heat mode.
  final List<IceShatter> shards = [];
  final List<IceCrack> cracks = [];
  final List<FireJump> jumps = [];
  final List<SteamPuff> steam = [];
  final List<HazardArrival> arrivals = [];
  DateTime? glint; // a diagonal shine across all blocks
  static const glintDuration = Duration(milliseconds: 750);

  /// Board shake after big explosions.
  DateTime? shakeStart;
  double shakePower = 0;
  static const shakeDuration = Duration(milliseconds: 420);

  bool get busy => flashes.isNotEmpty || beams.isNotEmpty || bursts.isNotEmpty || glint != null;

  void shake(DateTime now, double power) {
    shakeStart = now;
    shakePower = power;
  }

  /// Offset to move the board by for the shake, in cells.
  Offset shakeOffset(DateTime now) {
    final s = shakeStart;
    if (s == null) return Offset.zero;
    final t = now.difference(s).inMicroseconds / shakeDuration.inMicroseconds;
    if (t >= 1) return Offset.zero;
    final k = shakePower * (1 - t) * (1 - t);
    return Offset(sin(t * 70) * k, cos(t * 55) * k * 0.7);
  }

  void prune(DateTime now) {
    flashes.removeWhere((f) => now.difference(f.start) > PlaceFlash.duration);
    beams.removeWhere((b) => now.difference(b.start) > LineBeam.duration);
    bursts.removeWhere((b) => now.difference(b.start) > b.duration);
    shards.removeWhere((e) => now.difference(e.start) > IceShatter.duration);
    cracks.removeWhere((e) => now.difference(e.start) > IceCrack.duration);
    jumps.removeWhere((e) => now.difference(e.start) > FireJump.duration);
    steam.removeWhere((e) => now.difference(e.start) > SteamPuff.duration);
    arrivals.removeWhere((e) => now.difference(e.start) > HazardArrival.duration);
    if (glint != null && now.difference(glint!) > glintDuration) glint = null;
  }

  void clear() {
    flashes.clear();
    beams.clear();
    bursts.clear();
    shards.clear();
    cracks.clear();
    jumps.clear();
    steam.clear();
    arrivals.clear();
    glint = null;
    shakeStart = null;
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
    final seconds = (now.millisecondsSinceEpoch % 1000000) / 1000;
    final burning = <(int, int)>[];
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        final rect = rectAt(r, c);
        final v = game.board[r][c];
        final inClearLine = clearRows.contains(r) || clearCols.contains(c);
        if (v == frozenCell) {
          paintSkinEmpty(canvas, rect, skin);
          paintFrozenCell(canvas, rect, game.ice[r][c], seconds);
          if (inClearLine) {
            // The coming clear will crack this ice.
            canvas.drawRRect(
              RRect.fromRectAndRadius(rect.deflate(cell * 0.05), Radius.circular(cell * 0.12)),
              Paint()..color = Colors.white.withValues(alpha: 0.3),
            );
          }
          continue;
        }
        if (v >= 0 && game.fuse[r][c] > 0) burning.add((r, c));
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

    // Flames go on top of all blocks so they can lick into neighbours.
    for (final (r, c) in burning) {
      paintBurning(canvas, rectAt(r, c), game.fuse[r][c], seconds, r * boardSize + c);
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
      _paintShatter(canvas, rectAt(b.r, b.c), b.color, t, b.heat);
    }

    paintHeatFx(
      canvas,
      cell,
      now,
      shards: fx.shards,
      cracks: fx.cracks,
      jumps: fx.jumps,
      steam: fx.steam,
      arrivals: fx.arrivals,
    );
    paintBursts(canvas, cell, fx.bursts, now);
  }

  void _paintShatter(Canvas canvas, Rect rect, int colorIndex, double t, double heat) {
    final fire = heat >= 0.34;
    final w = rect.width;
    final base = skin.colors[colorIndex % skin.colors.length];
    final hot = fire ? const Color(0xFFFF8A2A) : const Color(0xFFE6F8FF);

    // First the block lights up (frost or flame) and swells a little.
    if (t < 0.28) {
      final k = t / 0.28;
      final grown = rect.inflate(w * 0.08 * k);
      paintSkinBlock(canvas, grown, colorIndex, skin);
      canvas.drawPath(skinPath(skin.shape, grown.deflate(w * 0.05)), Paint()..color = hot.withValues(alpha: 0.75 * k));
      canvas.drawCircle(
        rect.center,
        w * 0.7,
        Paint()
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.35)
          ..color = hot.withValues(alpha: 0.5 * k),
      );
      return;
    }

    // Then it breaks into four shards that fly apart, spin and fall.
    final k = (t - 0.28) / 0.72;
    final ease = Curves.easeOutCubic.transform(k);
    final fade = 1 - k;
    final c = rect.center;
    final half = w * 0.45;
    final corners = [
      c + Offset(-half, -half),
      c + Offset(half, -half),
      c + Offset(half, half),
      c + Offset(-half, half),
    ];
    final color = fire
        ? Color.lerp(Color.lerp(base, const Color(0xFFFF8A2A), 0.6)!, const Color(0xFF3A1A10), k)!
        : Color.lerp(base, Colors.white, 0.5 + 0.3 * k)!;
    for (var i = 0; i < 4; i++) {
      final a1 = corners[i], a2 = corners[(i + 1) % 4];
      final mid = Offset((a1.dx + a2.dx) / 2, (a1.dy + a2.dy) / 2);
      final dir = (mid - c) / half;
      final move = dir * w * 0.9 * ease + Offset(0, w * (fire ? -0.4 : 0.6) * k * k);
      final spin = (i.isEven ? 1 : -1) * 2.2 * ease;
      final centroid = (c + a1 + a2) / 3;
      canvas.save();
      canvas.translate(centroid.dx + move.dx, centroid.dy + move.dy);
      canvas.rotate(spin);
      canvas.scale(1 - 0.4 * k);
      final shard = Path()
        ..moveTo(c.dx - centroid.dx, c.dy - centroid.dy)
        ..lineTo(a1.dx - centroid.dx, a1.dy - centroid.dy)
        ..lineTo(a2.dx - centroid.dx, a2.dy - centroid.dy)
        ..close();
      if (fire) {
        canvas.drawPath(
          shard,
          Paint()
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.12)
            ..color = const Color(0xFFFF6A1A).withValues(alpha: 0.6 * fade),
        );
      }
      canvas.drawPath(shard, Paint()..color = color.withValues(alpha: fade));
      canvas.drawPath(
        shard,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(0.8, w * 0.03)
          ..color = (fire ? const Color(0xFFFFE08A) : Colors.white).withValues(alpha: 0.8 * fade),
      );
      canvas.restore();
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

/// The Blazegrid logo: a 3x3 block grid that runs from ice (top left) to
/// fire (bottom right), with a flame bursting out of the centre.
class LogoPainter extends CustomPainter {
  static const _ramp = [
    Color(0xFF7FD3FF),
    Color(0xFF4FA8F0),
    Color(0xFF8B7CF0),
    Color(0xFFFF9A3D),
    Color(0xFFFF6A2A),
    Color(0xFFE0301E),
  ];

  static const _logoSkin = Skin('Logo', SkinShape.neon, _ramp, Color(0xFF111729), Color(0xFF1A2238));

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 3;
    for (var i = 0; i < 9; i++) {
      if (i == 4) continue;
      final r = i ~/ 3, c = i % 3;
      // Ice at top left, fire at bottom right, drawn as neon blocks.
      paintSkinBlock(canvas, Rect.fromLTWH(c * cell, r * cell, cell, cell), const [0, 1, 2, 4, 5][r + c], _logoSkin);
    }
    paintLogoFlame(canvas, Offset(size.width / 2, size.height / 2), cell * 1.2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A flame with an icy core, drawn centred on [c] inside a cell of size [cell].
void paintLogoFlame(Canvas canvas, Offset c, double cell) {
  canvas.drawCircle(
    c,
    cell * 0.62,
    Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.22)
      ..color = const Color(0xFFFF8A2A).withValues(alpha: 0.75),
  );
  Path flame(double w, double h) {
    final base = c + Offset(0, cell * 0.36);
    return Path()
      ..moveTo(base.dx, base.dy)
      ..cubicTo(
        base.dx - w * 1.1,
        base.dy - h * 0.05,
        base.dx - w * 0.9,
        base.dy - h * 0.62,
        base.dx - w * 0.15,
        base.dy - h * 0.78,
      )
      ..quadraticBezierTo(base.dx - w * 0.05, base.dy - h * 0.5, base.dx + w * 0.2, base.dy - h * 0.42)
      ..quadraticBezierTo(base.dx + w * 0.35, base.dy - h * 0.85, base.dx + w * 0.05, base.dy - h)
      ..cubicTo(base.dx + w * 1.0, base.dy - h * 0.7, base.dx + w * 1.15, base.dy - h * 0.1, base.dx, base.dy)
      ..close();
  }

  canvas.drawPath(flame(cell * 0.46, cell * 0.95), Paint()..color = const Color(0xFFE0301E));
  canvas.drawPath(flame(cell * 0.36, cell * 0.76), Paint()..color = const Color(0xFFFF7A1A));
  canvas.drawPath(flame(cell * 0.24, cell * 0.52), Paint()..color = const Color(0xFFFFC23D));
  // Icy core: a small white-blue diamond.
  final core = c + Offset(0, cell * 0.18);
  final d = cell * 0.1;
  canvas.drawPath(
    Path()
      ..moveTo(core.dx, core.dy - d * 1.5)
      ..lineTo(core.dx + d, core.dy)
      ..lineTo(core.dx, core.dy + d * 1.2)
      ..lineTo(core.dx - d, core.dy)
      ..close(),
    Paint()..color = const Color(0xFFE6F8FF),
  );
}

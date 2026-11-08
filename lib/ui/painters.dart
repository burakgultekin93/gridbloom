import 'dart:math';

import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/pieces.dart';
import 'palette.dart';

/// Draws one block as a soft rounded tile.
void paintBlock(Canvas canvas, Rect rect, Color color, {double opacity = 1}) {
  final r = RRect.fromRectAndRadius(rect.deflate(rect.width * 0.05), Radius.circular(rect.width * 0.2));
  canvas.drawRRect(r, Paint()..color = color.withValues(alpha: opacity));
  // Light top band for depth.
  final top = RRect.fromRectAndCorners(
    Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.35),
    topLeft: r.tlRadius,
    topRight: r.trRadius,
  );
  canvas.drawRRect(top, Paint()..color = Colors.white.withValues(alpha: 0.18 * opacity));
}

/// A flower that opens and fades where a block was cleared.
class Bloom {
  final int r, c, color;
  final DateTime start;
  Bloom(this.r, this.c, this.color, this.start);
  static const duration = Duration(milliseconds: 700);
}

class BoardPainter extends CustomPainter {
  final GameState game;
  final PieceShape? ghost;
  final int ghostRow, ghostCol, ghostColor;
  final List<int> clearRows, clearCols;
  final List<Bloom> blooms;
  final DateTime now;

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
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / boardSize;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cell * 0.35)),
      Paint()..color = Palette.board,
    );
    final pad = cell * 0.0;
    Rect rectAt(int r, int c) => Rect.fromLTWH(pad + c * cell, pad + r * cell, cell, cell);

    final ghostCells = <int>{};
    if (ghost != null) {
      for (final g in ghost!.cells) {
        ghostCells.add((ghostRow + g.r) * boardSize + ghostCol + g.c);
      }
    }

    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        final rect = rectAt(r, c);
        final v = game.board[r][c];
        final inClearLine = clearRows.contains(r) || clearCols.contains(c);
        if (v >= 0) {
          // Blocks in a line about to clear take the dragged piece's colour.
          paintBlock(canvas, rect, Palette.blocks[inClearLine ? ghostColor : v]);
        } else if (ghostCells.contains(r * boardSize + c)) {
          paintBlock(canvas, rect, Palette.blocks[ghostColor], opacity: 0.55);
        } else {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect.deflate(cell * 0.06), Radius.circular(cell * 0.18)),
            Paint()..color = Palette.emptyCell,
          );
        }
        if (inClearLine && (v >= 0 || ghostCells.contains(r * boardSize + c))) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect.deflate(cell * 0.05), Radius.circular(cell * 0.2)),
            Paint()..color = Colors.white.withValues(alpha: 0.25),
          );
        }
      }
    }

    for (final b in blooms) {
      final t = now.difference(b.start).inMilliseconds / Bloom.duration.inMilliseconds;
      if (t < 0 || t > 1) continue;
      _paintBloom(canvas, rectAt(b.r, b.c), b.color, t);
    }
  }

  void _paintBloom(Canvas canvas, Rect rect, int color, double t) {
    final center = rect.center;
    final grow = Curves.easeOutBack.transform(min(1, t * 1.6));
    final fade = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
    final petalR = rect.width * 0.2 * grow;
    final dist = rect.width * 0.22 * grow;
    final petal = Paint()..color = Palette.petals[color].withValues(alpha: fade);
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * pi / 5 - pi / 2 + t * 0.8;
      canvas.drawCircle(center + Offset(cos(a), sin(a)) * dist, petalR, petal);
    }
    canvas.drawCircle(center, petalR * 0.8, Paint()..color = Palette.blocks[2].withValues(alpha: fade));
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
  PiecePainter(this.shape, this.color, this.cell, {this.opacity = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final ox = (size.width - shape.cols * cell) / 2;
    final oy = (size.height - shape.rows * cell) / 2;
    for (final c in shape.cells) {
      paintBlock(canvas, Rect.fromLTWH(ox + c.c * cell, oy + c.r * cell, cell, cell), Palette.blocks[color],
          opacity: opacity);
    }
  }

  @override
  bool shouldRepaint(covariant PiecePainter old) =>
      old.shape != shape || old.color != color || old.cell != cell || old.opacity != opacity;
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

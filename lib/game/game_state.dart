import 'dart:math';

import 'pieces.dart';

const int boardSize = 8;

/// A piece waiting in the tray, with its colour index.
class TrayPiece {
  final PieceShape shape;
  final int color;
  const TrayPiece(this.shape, this.color);
}

/// What a single placement did, used by the UI for effects.
class MoveResult {
  final int points;
  final int linesCleared;
  final int multiplier;
  final bool boardCleared;

  /// Cells removed by the clear, with the colour they had.
  final List<(int, int, int)> clearedCells;
  const MoveResult({
    required this.points,
    required this.linesCleared,
    required this.multiplier,
    required this.boardCleared,
    required this.clearedCells,
  });
}

/// Pure game rules: board, tray, scoring, piece generation.
class GameState {
  static const int colorCount = 6;

  /// -1 = empty, otherwise a colour index.
  final List<List<int>> board;
  final List<TrayPiece?> tray;
  int score;
  int streak; // consecutive clearing moves
  int movesSinceClear;
  bool gameOver;
  final Random _rng;

  GameState({Random? rng})
      : board = List.generate(boardSize, (_) => List.filled(boardSize, -1)),
        tray = [null, null, null],
        score = 0,
        streak = 0,
        movesSinceClear = 0,
        gameOver = false,
        _rng = rng ?? Random() {
    _refillTray();
  }

  bool canPlace(PieceShape shape, int row, int col) {
    for (final cell in shape.cells) {
      final r = row + cell.r, c = col + cell.c;
      if (r < 0 || c < 0 || r >= boardSize || c >= boardSize) return false;
      if (board[r][c] != -1) return false;
    }
    return true;
  }

  bool fitsAnywhere(PieceShape shape) {
    for (var r = 0; r <= boardSize - shape.rows; r++) {
      for (var c = 0; c <= boardSize - shape.cols; c++) {
        if (canPlace(shape, r, c)) return true;
      }
    }
    return false;
  }

  /// Rows and columns that would be completed if [shape] went at (row, col).
  ({List<int> rows, List<int> cols}) previewClears(
      PieceShape shape, int row, int col) {
    final filled = <int>{for (final c in shape.cells) (row + c.r) * boardSize + col + c.c};
    bool on(int r, int c) => board[r][c] != -1 || filled.contains(r * boardSize + c);
    final rows = <int>[], cols = <int>[];
    for (var r = 0; r < boardSize; r++) {
      if (List.generate(boardSize, (c) => on(r, c)).every((x) => x)) rows.add(r);
    }
    for (var c = 0; c < boardSize; c++) {
      if (List.generate(boardSize, (r) => on(r, c)).every((x) => x)) cols.add(c);
    }
    return (rows: rows, cols: cols);
  }

  static int linePoints(int lines) {
    if (lines <= 0) return 0;
    if (lines == 1) return 10;
    if (lines == 2) return 30;
    if (lines == 3) return 60;
    return 60 + (lines - 3) * 25;
  }

  /// Places tray piece [index] at (row, col). Returns null if illegal.
  MoveResult? place(int index, int row, int col) {
    final piece = tray[index];
    if (piece == null || gameOver || !canPlace(piece.shape, row, col)) return null;

    for (final cell in piece.shape.cells) {
      board[row + cell.r][col + cell.c] = piece.color;
    }
    tray[index] = null;
    var points = piece.shape.cells.length;

    final full = previewClears(PieceShape('', const [], PieceSize.small), 0, 0);
    final lines = full.rows.length + full.cols.length;
    final cleared = <(int, int, int)>[];
    final seen = <int>{};
    void take(int r, int c) {
      if (seen.add(r * boardSize + c)) cleared.add((r, c, board[r][c]));
    }

    for (final r in full.rows) {
      for (var c = 0; c < boardSize; c++) {
        take(r, c);
      }
    }
    for (final c in full.cols) {
      for (var r = 0; r < boardSize; r++) {
        take(r, c);
      }
    }
    for (final (r, c, _) in cleared) {
      board[r][c] = -1;
    }

    var multiplier = 1;
    var boardCleared = false;
    if (lines > 0) {
      streak += 1;
      movesSinceClear = 0;
      multiplier = streak;
      points += linePoints(lines) * multiplier;
      boardCleared = board.every((row) => row.every((v) => v == -1));
      if (boardCleared) points += 300;
    } else {
      movesSinceClear += 1;
      if (movesSinceClear >= 3) streak = 0;
    }
    score += points;

    if (tray.every((p) => p == null)) _refillTray();
    gameOver = !tray.any((p) => p != null && fitsAnywhere(p.shape));

    return MoveResult(
      points: points,
      linesCleared: lines,
      multiplier: multiplier,
      boardCleared: boardCleared,
      clearedCells: cleared,
    );
  }

  int _weight(PieceShape s) {
    switch (s.size) {
      case PieceSize.small:
        return 6;
      case PieceSize.medium:
        return 4;
      case PieceSize.large:
        // Large pieces get more common as the score climbs.
        return 1 + min(score ~/ 1000, 3);
    }
  }

  PieceShape _randomShape() {
    final total = allPieces.fold<int>(0, (a, s) => a + _weight(s));
    var roll = _rng.nextInt(total);
    for (final s in allPieces) {
      roll -= _weight(s);
      if (roll < 0) return s;
    }
    return allPieces.last;
  }

  void _refillTray() {
    for (var attempt = 0; attempt < 30; attempt++) {
      final shapes = List.generate(3, (_) => _randomShape());
      if (shapes.any(fitsAnywhere)) {
        _setTray(shapes);
        return;
      }
    }
    // Fairness fallback: guarantee at least one piece that fits.
    final fitting = allPieces.where(fitsAnywhere).toList();
    final shapes = List.generate(3, (_) => _randomShape());
    if (fitting.isNotEmpty) shapes[0] = fitting[_rng.nextInt(fitting.length)];
    _setTray(shapes);
  }

  void _setTray(List<PieceShape> shapes) {
    for (var i = 0; i < 3; i++) {
      tray[i] = TrayPiece(shapes[i], _rng.nextInt(colorCount));
    }
  }

  Map<String, dynamic> toJson() => {
        'board': board.map((r) => List<int>.from(r)).toList(),
        'tray': tray.map((p) => p == null ? null : {'id': p.shape.id, 'color': p.color}).toList(),
        'score': score,
        'streak': streak,
        'movesSinceClear': movesSinceClear,
      };

  static GameState? fromJson(Map<String, dynamic> j) {
    try {
      final g = GameState();
      final b = (j['board'] as List).map((r) => (r as List).cast<int>()).toList();
      for (var r = 0; r < boardSize; r++) {
        for (var c = 0; c < boardSize; c++) {
          g.board[r][c] = b[r][c];
        }
      }
      final t = j['tray'] as List;
      for (var i = 0; i < 3; i++) {
        final e = t[i];
        g.tray[i] = e == null ? null : TrayPiece(piecesById[e['id']]!, e['color'] as int);
      }
      g.score = j['score'] as int;
      g.streak = j['streak'] as int;
      g.movesSinceClear = j['movesSinceClear'] as int;
      if (g.tray.every((p) => p == null)) g._refillTray();
      g.gameOver = !g.tray.any((p) => p != null && g.fitsAnywhere(p.shape));
      return g;
    } catch (_) {
      return null;
    }
  }
}

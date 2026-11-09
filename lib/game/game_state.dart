import 'dart:math';

import 'pieces.dart';

const int boardSize = 8;

/// Number of block looks; the look moves on each time the board is cleared.
const int skinCount = 4;

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

  /// Cells the piece was placed on, and the rows/columns that cleared.
  final List<(int, int)> placedCells;
  final List<int> clearedRows;
  final List<int> clearedCols;

  /// The block look changed because the board was cleared.
  final bool skinChanged;

  /// Mini goals finished by this move; their bonus is included in [points].
  final List<Goal> goalsDone;
  const MoveResult({
    required this.points,
    required this.linesCleared,
    required this.multiplier,
    required this.boardCleared,
    required this.clearedCells,
    this.placedCells = const [],
    this.clearedRows = const [],
    this.clearedCols = const [],
    this.skinChanged = false,
    this.goalsDone = const [],
  });
}

/// Small per-game tasks that give bonus points.
enum Goal { streak3, double, triple, lines10, bigMove, streak5 }

const goalText = <Goal, String>{
  Goal.streak3: "3'lü seri yap",
  Goal.double: 'Aynı anda 2 çizgi',
  Goal.triple: 'Aynı anda 3 çizgi',
  Goal.lines10: '10 çizgi patlat',
  Goal.bigMove: 'Tek hamlede 100 puan',
  Goal.streak5: "5'li seri yap",
};

const goalBonus = <Goal, int>{
  Goal.streak3: 150,
  Goal.double: 100,
  Goal.triple: 250,
  Goal.lines10: 200,
  Goal.bigMove: 150,
  Goal.streak5: 300,
};

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

  /// Which block look is active (0 .. skinCount-1).
  int skin;

  /// The player's record when this game started. Used, quietly, to make
  /// piece luck a little kinder when the player is close to beating it.
  int best;

  /// This game's mini goals and which of them are done.
  final List<Goal> goals;
  final Set<Goal> goalsDone;
  int linesTotal;
  final Random _rng;

  GameState({Random? rng, this.best = 0})
    : board = List.generate(boardSize, (_) => List.filled(boardSize, -1)),
      tray = [null, null, null],
      score = 0,
      streak = 0,
      movesSinceClear = 0,
      gameOver = false,
      skin = 0,
      goals = [],
      goalsDone = {},
      linesTotal = 0,
      _rng = rng ?? Random() {
    _pickGoals();
    _refillTray();
  }

  /// Two easier goals and one hard one.
  void _pickGoals() {
    final easy = [Goal.double, Goal.streak3, Goal.lines10]..shuffle(_rng);
    final hard = [Goal.triple, Goal.bigMove, Goal.streak5]..shuffle(_rng);
    goals
      ..clear()
      ..addAll([easy[0], easy[1], hard[0]]);
  }

  /// How hot the streak is, from 0 (cold) to 1 (on fire). A streak of 6
  /// clearing moves is full fire; each move without a clear cools it.
  double get heat {
    if (streak == 0) return 0;
    final base = min(streak, 6) / 6;
    return (base * (1 - movesSinceClear * 0.25)).clamp(0.0, 1.0);
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
  ({List<int> rows, List<int> cols}) previewClears(PieceShape shape, int row, int col) {
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
      if (boardCleared) {
        points += 300;
        skin = (skin + 1) % skinCount;
      }
    } else {
      movesSinceClear += 1;
      if (movesSinceClear >= 3) streak = 0;
    }
    linesTotal += lines;
    final done = <Goal>[];
    for (final g in goals) {
      if (goalsDone.contains(g)) continue;
      final hit = switch (g) {
        Goal.streak3 => streak >= 3,
        Goal.double => lines >= 2,
        Goal.triple => lines >= 3,
        Goal.lines10 => linesTotal >= 10,
        Goal.bigMove => points >= 100,
        Goal.streak5 => streak >= 5,
      };
      if (hit) done.add(g);
    }
    for (final g in done) {
      goalsDone.add(g);
      points += goalBonus[g]!;
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
      placedCells: [for (final c in piece.shape.cells) (row + c.r, col + c.c)],
      clearedRows: full.rows,
      clearedCols: full.cols,
      skinChanged: boardCleared,
      goalsDone: done,
    );
  }

  /// Share of the board that is filled, 0..1.
  double get fill => board.fold<int>(0, (n, row) => n + row.where((v) => v != -1).length) / (boardSize * boardSize);

  /// How much quiet help the next tray gets, 0 (none) to 1 (a lot).
  /// The player never sees this: pieces still look random.
  double get assist {
    var a = 0.0;
    // Warm-up: the first stretch of every game is gentle.
    if (score < 800) a = 1.0 - score / 800 * 0.5;
    // Rescue when the board is getting crowded.
    if (fill > 0.65) a = max(a, ((fill - 0.65) / 0.2).clamp(0.0, 1.0) * 0.8);
    // Record chase: close to the record, but only for reachable records.
    if (best > 0 && best < 20000 && score >= best * 0.8 && score <= best * 1.05) a = max(a, 0.6);
    return a;
  }

  int _weight(PieceShape s) {
    final rescue = fill > 0.65;
    switch (s.size) {
      case PieceSize.small:
        return rescue ? 12 : 6;
      case PieceSize.medium:
        return 4;
      case PieceSize.large:
        if (score < 800) return 0; // none during warm-up
        if (rescue) return 1;
        if (score < 3000) return 1 + score ~/ 1500; // 1..2
        return 3 + min((score - 3000) ~/ 2000, 3); // 3..6, gets harder
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

  /// Can all three pieces be placed one after another (some order, placing
  /// each where it clears the most)? Returns -1 if not, else the number of
  /// lines a simple player would clear.
  int _playable(List<PieceShape> shapes) {
    var bestLines = -1;
    for (final order in const [
      [0, 1, 2],
      [0, 2, 1],
      [1, 0, 2],
      [1, 2, 0],
      [2, 0, 1],
      [2, 1, 0],
    ]) {
      final b = [for (final row in board) List<int>.from(row)];
      var lines = 0;
      var ok = true;
      for (final i in order) {
        final placed = _greedyPlace(b, shapes[i]);
        if (placed < 0) {
          ok = false;
          break;
        }
        lines += placed;
      }
      if (ok && lines > bestLines) bestLines = lines;
    }
    return bestLines;
  }

  /// Puts [shape] on board [b] where it clears the most lines (ties: first
  /// spot), removes the cleared lines, and returns how many cleared, or -1.
  static int _greedyPlace(List<List<int>> b, PieceShape shape) {
    var bestR = -1, bestC = -1, bestLines = -1;
    for (var r = 0; r <= boardSize - shape.rows; r++) {
      for (var c = 0; c <= boardSize - shape.cols; c++) {
        if (!shape.cells.every((e) => b[r + e.r][c + e.c] == -1)) continue;
        for (final e in shape.cells) {
          b[r + e.r][c + e.c] = 0;
        }
        var lines = 0;
        for (var i = 0; i < boardSize; i++) {
          if (b[i].every((v) => v != -1)) lines++;
          if (List.generate(boardSize, (k) => b[k][i]).every((v) => v != -1)) lines++;
        }
        for (final e in shape.cells) {
          b[r + e.r][c + e.c] = -1;
        }
        if (lines > bestLines) {
          bestLines = lines;
          bestR = r;
          bestC = c;
        }
      }
    }
    if (bestLines < 0) return -1;
    for (final e in shape.cells) {
      b[bestR + e.r][bestC + e.c] = 0;
    }
    final rows = [
      for (var i = 0; i < boardSize; i++)
        if (b[i].every((v) => v != -1)) i,
    ];
    final cols = [
      for (var i = 0; i < boardSize; i++)
        if (List.generate(boardSize, (k) => b[k][i]).every((v) => v != -1)) i,
    ];
    for (final r in rows) {
      for (var c = 0; c < boardSize; c++) {
        b[r][c] = -1;
      }
    }
    for (final c in cols) {
      for (var r = 0; r < boardSize; r++) {
        b[r][c] = -1;
      }
    }
    return bestLines;
  }

  /// Does any piece in [shapes] complete a line somewhere right now?
  bool _canClear(List<PieceShape> shapes) {
    for (final s in shapes) {
      for (var r = 0; r <= boardSize - s.rows; r++) {
        for (var c = 0; c <= boardSize - s.cols; c++) {
          if (!canPlace(s, r, c)) continue;
          final p = previewClears(s, r, c);
          if (p.rows.isNotEmpty || p.cols.isNotEmpty) return true;
        }
      }
    }
    return false;
  }

  void _refillTray() {
    final a = assist;
    // More help means more candidate trays to choose the kindest from.
    final candidates = 1 + (a * 8).round() + (score < 3000 ? 2 : 0);
    List<PieceShape>? pick;
    var pickScore = -1.0;
    for (var k = 0; k < candidates; k++) {
      final shapes = List.generate(3, (_) => _randomShape());
      if (!shapes.any(fitsAnywhere)) continue;
      final lines = _playable(shapes);
      var q = _rng.nextDouble() * 0.5; // keep some randomness
      if (lines >= 0) q += 2 + min(lines, 3) * a; // all three fit
      if (_canClear(shapes)) q += 1; // helper hand: a line can be finished
      if (q > pickScore) {
        pickScore = q;
        pick = shapes;
      }
    }
    if (pick != null) {
      _setTray(pick);
      return;
    }
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
    'skin': skin,
    'best': best,
    'goals': goals.map((g) => g.name).toList(),
    'goalsDone': goalsDone.map((g) => g.name).toList(),
    'linesTotal': linesTotal,
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
      g.skin = (j['skin'] as int? ?? 0) % skinCount;
      g.best = j['best'] as int? ?? 0;
      g.linesTotal = j['linesTotal'] as int? ?? 0;
      final goals = (j['goals'] as List?)?.map((n) => Goal.values.byName(n as String)).toList();
      if (goals != null && goals.length == 3) {
        g.goals
          ..clear()
          ..addAll(goals);
      }
      g.goalsDone.addAll(((j['goalsDone'] as List?) ?? const []).map((n) => Goal.values.byName(n as String)));
      if (g.tray.every((p) => p == null)) g._refillTray();
      g.gameOver = !g.tray.any((p) => p != null && g.fitsAnywhere(p.shape));
      return g;
    } catch (_) {
      return null;
    }
  }
}

import 'dart:math';

import 'game_config.dart';
import 'pieces.dart';

const int boardSize = 8;

/// Number of block looks; the look moves on each time the board is cleared.
const int skinCount = 4;

/// Board value of a frozen cell (empty cells are -1, blocks are 0..5).
const int frozenCell = -2;

/// Classic: plain block puzzle. Heat: frozen cells and spreading fire.
enum GameMode { classic, heat }

/// What happened to one ice cell during a move.
enum IceHit { cracked, melted }

/// One heat mode event on a cell, for effects.
class HeatEvent {
  final int r, c;
  const HeatEvent(this.r, this.c);
}

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

  // ---- Heat mode ----

  /// Ice cells hit by this move (a line or a neighbour cleared), and
  /// whether they only cracked or melted away.
  final List<(int, int, IceHit)> iceHits;

  /// Burning blocks put out because their line cleared.
  final List<(int, int)> doused;

  /// Fire that jumped to a new cell this move: (from, to).
  final List<((int, int), (int, int))> spread;

  /// Fire that ran into ice: both went out in a puff of steam.
  final List<(int, int)> steam;

  /// The hazard wave that arrived after this move.
  final List<(int, int)> newIce;
  final List<(int, int)> ignited;

  /// Bonus points for melting ice and putting out fire (in [points]).
  final int heatBonus;

  /// Hot streak: ice next to the clear melted in one go.
  final bool hotMelt;

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
    this.iceHits = const [],
    this.doused = const [],
    this.spread = const [],
    this.steam = const [],
    this.newIce = const [],
    this.ignited = const [],
    this.heatBonus = 0,
    this.hotMelt = false,
  });

  int get melted => iceHits.where((h) => h.$3 == IceHit.melted).length;
}

/// Small per-game tasks that give bonus points.
enum Goal { streak3, double, triple, lines10, bigMove, streak5, thaw5, douse2, thaw12, douse5 }

const goalText = <Goal, String>{
  Goal.streak3: "3'lü seri yap",
  Goal.double: 'Aynı anda 2 çizgi',
  Goal.triple: 'Aynı anda 3 çizgi',
  Goal.lines10: '10 çizgi patlat',
  Goal.bigMove: 'Tek hamlede 100 puan',
  Goal.streak5: "5'li seri yap",
  Goal.thaw5: '5 buz çöz',
  Goal.douse2: '2 ateş söndür',
  Goal.thaw12: '12 buz çöz',
  Goal.douse5: '5 ateş söndür',
};

const goalBonus = <Goal, int>{
  Goal.streak3: 150,
  Goal.double: 100,
  Goal.triple: 250,
  Goal.lines10: 200,
  Goal.bigMove: 150,
  Goal.streak5: 300,
  Goal.thaw5: 150,
  Goal.douse2: 150,
  Goal.thaw12: 300,
  Goal.douse5: 300,
};

/// Points for each ice cell melted and each fire put out in heat mode.
const int meltPoints = 20;
const int dousePoints = 30;

/// Pure game rules: board, tray, scoring, piece generation.
class GameState {
  static const int colorCount = 6;

  /// -1 = empty, [frozenCell] = ice, otherwise a colour index.
  final List<List<int>> board;

  final GameMode mode;

  /// Heat mode: layers of ice on each frozen cell (0 = not frozen).
  final List<List<int>> ice;

  /// Heat mode: moves left before a burning block spreads (0 = not burning).
  final List<List<int>> fuse;

  /// Heat mode: moves until the next hazard wave, and how many came so far.
  /// Waves take turns: ice, fire, ice, fire...
  int movesToWave;
  int waves;
  int thawedTotal;
  int dousedTotal;
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

  /// Tuning values for this game. Fixed when the game starts, so a Remote
  /// Config update never changes the rules in the middle of a game.
  final GameConfig config;
  final Random _rng;

  GameState({Random? rng, this.best = 0, GameConfig? config, this.mode = GameMode.classic})
    : config = config ?? GameConfig.current,
      board = List.generate(boardSize, (_) => List.filled(boardSize, -1)),
      ice = List.generate(boardSize, (_) => List.filled(boardSize, 0)),
      fuse = List.generate(boardSize, (_) => List.filled(boardSize, 0)),
      movesToWave = 0,
      waves = 0,
      thawedTotal = 0,
      dousedTotal = 0,
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
    if (mode == GameMode.heat) {
      movesToWave = this.config.heatWaveEvery;
      _seedIce(this.config.heatStartIce);
    }
    _refillTray();
  }

  bool get isHeat => mode == GameMode.heat;

  /// Two easier goals and one hard one.
  void _pickGoals() {
    final easy = isHeat
        ? ([Goal.thaw5, Goal.douse2, Goal.double]..shuffle(_rng))
        : ([Goal.double, Goal.streak3, Goal.lines10]..shuffle(_rng));
    final hard = isHeat
        ? ([Goal.thaw12, Goal.douse5, Goal.streak5]..shuffle(_rng))
        : ([Goal.triple, Goal.bigMove, Goal.streak5]..shuffle(_rng));
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

  /// Frozen cells at the start of a heat game: spread out, one per row and
  /// column at most, away from the corners so they never trap a corner.
  void _seedIce(int count) {
    final rows = List.generate(boardSize, (i) => i)..shuffle(_rng);
    final cols = List.generate(boardSize, (i) => i)..shuffle(_rng);
    var placed = 0;
    for (var i = 0; i < boardSize && placed < count; i++) {
      final r = rows[i], c = cols[i];
      if ((r == 0 || r == boardSize - 1) && (c == 0 || c == boardSize - 1)) continue;
      board[r][c] = frozenCell;
      ice[r][c] = 1;
      placed++;
    }
  }

  int get burningCount => fuse.fold<int>(0, (n, row) => n + row.where((f) => f > 0).length);

  int get iceCount => ice.fold<int>(0, (n, row) => n + row.where((l) => l > 0).length);

  /// The next hazard wave brings fire (true) or ice (false).
  bool get nextWaveIsFire => waves.isOdd;

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
    // Ice in a cleared line is hit, but stays in place until it melts.
    final iceInLines = [
      for (final (r, c, v) in cleared)
        if (v == frozenCell) (r, c),
    ];
    cleared.removeWhere((e) => e.$3 == frozenCell);
    final doused = <(int, int)>[];
    for (final (r, c, _) in cleared) {
      board[r][c] = -1;
      if (fuse[r][c] > 0) {
        fuse[r][c] = 0;
        doused.add((r, c));
      }
    }

    // Heat mode: clears crack the ice they touch. On a hot streak (the 4th
    // clearing move in a row or more) the heat melts it in one go.
    final iceHits = <(int, int, IceHit)>[];
    final hotMelt = isHeat && lines > 0 && streak + 1 >= 4;
    if (isHeat && lines > 0) {
      final hit = <int>{};
      void hitIce(int r, int c) {
        if (r < 0 || c < 0 || r >= boardSize || c >= boardSize) return;
        if (board[r][c] != frozenCell || !hit.add(r * boardSize + c)) return;
        iceHits.add((r, c, _crack(r, c, all: hotMelt)));
      }

      for (final (r, c) in iceInLines) {
        hitIce(r, c);
      }
      for (final (r, c, _) in cleared) {
        hitIce(r - 1, c);
        hitIce(r + 1, c);
        hitIce(r, c - 1);
        hitIce(r, c + 1);
      }
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

    // Heat mode: burning blocks tick down and spread, then the next wave.
    final spread = <((int, int), (int, int))>[];
    final steam = <(int, int)>[];
    final newIce = <(int, int)>[];
    final ignited = <(int, int)>[];
    if (isHeat) {
      _burn(spread, steam, iceHits);
      movesToWave -= 1;
      if (movesToWave <= 0) {
        movesToWave = config.heatWaveEvery;
        if (nextWaveIsFire) {
          _igniteWave(ignited);
        } else {
          _iceWave(newIce);
        }
        waves += 1;
      }
    }
    final melted = iceHits.where((h) => h.$3 == IceHit.melted).length;
    thawedTotal += melted;
    dousedTotal += doused.length;
    final heatBonus = melted * meltPoints + doused.length * dousePoints;
    points += heatBonus;

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
        Goal.thaw5 => thawedTotal >= 5,
        Goal.douse2 => dousedTotal >= 2,
        Goal.thaw12 => thawedTotal >= 12,
        Goal.douse5 => dousedTotal >= 5,
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
      iceHits: iceHits,
      doused: doused,
      spread: spread,
      steam: steam,
      newIce: newIce,
      ignited: ignited,
      heatBonus: heatBonus,
      hotMelt: hotMelt && iceHits.isNotEmpty,
    );
  }

  /// Takes one layer (or, with [all], every layer) off the ice at (r, c).
  IceHit _crack(int r, int c, {bool all = false}) {
    ice[r][c] = all ? 0 : ice[r][c] - 1;
    if (ice[r][c] > 0) return IceHit.cracked;
    ice[r][c] = 0;
    board[r][c] = -1;
    return IceHit.melted;
  }

  /// Every burning block gets one move closer to spreading. When its fuse
  /// runs out the block burns out (it stays as a plain block) and the fire
  /// jumps to a neighbour: an empty cell fills with a burning block, a block
  /// catches fire, and ice meets fire in a puff of steam that ends both.
  void _burn(List<((int, int), (int, int))> spread, List<(int, int)> steam, List<(int, int, IceHit)> iceHits) {
    final burning = <(int, int)>[
      for (var r = 0; r < boardSize; r++)
        for (var c = 0; c < boardSize; c++)
          if (fuse[r][c] > 0) (r, c),
    ];
    for (final (r, c) in burning) {
      if (fuse[r][c] <= 0) continue; // put out by steam this move
      fuse[r][c] -= 1;
      if (fuse[r][c] > 0) continue;
      final targets = <(int, int)>[
        for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)])
          if (r + dr >= 0 && r + dr < boardSize && c + dc >= 0 && c + dc < boardSize && fuse[r + dr][c + dc] == 0)
            (r + dr, c + dc),
      ];
      if (targets.isEmpty) continue; // burns out with nowhere to go
      final (tr, tc) = targets[_rng.nextInt(targets.length)];
      final v = board[tr][tc];
      if (v == frozenCell) {
        steam.add((tr, tc));
        iceHits.add((tr, tc, _crack(tr, tc)));
        continue;
      }
      if (v == -1) board[tr][tc] = board[r][c] < 0 ? 0 : board[r][c];
      fuse[tr][tc] = config.heatFuse;
      spread.add(((r, c), (tr, tc)));
    }
  }

  /// Ice wave: one or two new frozen cells on empty spots. Later in the game
  /// some of them are thicker (two layers). Skipped on a crowded board.
  void _iceWave(List<(int, int)> out) {
    final empty = <(int, int)>[
      for (var r = 0; r < boardSize; r++)
        for (var c = 0; c < boardSize; c++)
          if (board[r][c] == -1) (r, c),
    ];
    if (fill > config.heatWaveMaxFill) return;
    empty.shuffle(_rng);
    final count = min(empty.length, score >= 2500 ? 2 : 1);
    for (var i = 0; i < count; i++) {
      final (r, c) = empty[i];
      board[r][c] = frozenCell;
      ice[r][c] = score >= 1500 && _rng.nextDouble() < 0.35 ? 2 : 1;
      out.add((r, c));
    }
  }

  /// Fire wave: a block on the board catches fire. Nothing happens if there
  /// are no blocks or enough fires already.
  void _igniteWave(List<(int, int)> out) {
    if (burningCount >= config.heatMaxFires) return;
    final blocks = <(int, int)>[
      for (var r = 0; r < boardSize; r++)
        for (var c = 0; c < boardSize; c++)
          if (board[r][c] >= 0 && fuse[r][c] == 0) (r, c),
    ];
    if (blocks.isEmpty) return;
    final (r, c) = blocks[_rng.nextInt(blocks.length)];
    fuse[r][c] = config.heatFuse;
    out.add((r, c));
  }

  /// Share of the board that is filled, 0..1.
  double get fill => board.fold<int>(0, (n, row) => n + row.where((v) => v != -1).length) / (boardSize * boardSize);

  /// How much quiet help the next tray gets, 0 (none) to 1 (a lot).
  /// The player never sees this: pieces still look random.
  double get assist {
    final k = config;
    if (!k.assistEnabled) return 0;
    var a = 0.0;
    // Warm-up: the first stretch of every game is gentle.
    if (score < k.warmupScore) a = k.assistWarmup * (1.0 - score / k.warmupScore * 0.5);
    // Rescue when the board is getting crowded.
    if (fill > k.rescueFill) a = max(a, ((fill - k.rescueFill) / 0.2).clamp(0.0, 1.0) * k.assistRescue);
    // Record chase: close to the record, but only for reachable records.
    if (best > 0 && best < k.recordAssistMaxBest && score >= best * 0.8 && score <= best * 1.05) {
      a = max(a, k.assistRecord);
    }
    return a;
  }

  int _weight(PieceShape s) => config.pieceWeight(s, score, rescue: fill > config.rescueFill);

  PieceShape _randomShape() {
    final total = allPieces.fold<int>(0, (a, s) => a + _weight(s));
    if (total <= 0) return allPieces[_rng.nextInt(allPieces.length)];
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
    final candidates = 1 + (a * config.assistExtraTrays).round() + (score < config.hardScore ? 2 : 0);
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
    'mode': mode.name,
    if (isHeat) ...{
      'ice': ice.map((r) => List<int>.from(r)).toList(),
      'fuse': fuse.map((r) => List<int>.from(r)).toList(),
      'movesToWave': movesToWave,
      'waves': waves,
      'thawed': thawedTotal,
      'doused': dousedTotal,
    },
  };

  static GameState? fromJson(Map<String, dynamic> j) {
    try {
      final mode = GameMode.values.byName(j['mode'] as String? ?? 'classic');
      final g = GameState(mode: mode);
      final b = (j['board'] as List).map((r) => (r as List).cast<int>()).toList();
      final ice = (j['ice'] as List?)?.map((r) => (r as List).cast<int>()).toList();
      final fuse = (j['fuse'] as List?)?.map((r) => (r as List).cast<int>()).toList();
      for (var r = 0; r < boardSize; r++) {
        for (var c = 0; c < boardSize; c++) {
          g.board[r][c] = b[r][c];
          g.ice[r][c] = ice?[r][c] ?? 0;
          g.fuse[r][c] = fuse?[r][c] ?? 0;
        }
      }
      g.movesToWave = j['movesToWave'] as int? ?? g.config.heatWaveEvery;
      g.waves = j['waves'] as int? ?? 0;
      g.thawedTotal = j['thawed'] as int? ?? 0;
      g.dousedTotal = j['doused'] as int? ?? 0;
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

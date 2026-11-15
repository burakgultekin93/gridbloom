// ignore_for_file: avoid_print
// Plays many games with a simple bot to check the difficulty curve.
// Run: dart run tool/simulate.dart [games] [classic|heat]
import 'dart:math';

import 'package:blazegrid/game/game_state.dart';

/// One move: try every piece and spot, keep the best by a simple score.
bool _move(GameState g) {
  (int, int, int)? best;
  var bestScore = -1e9;
  for (var i = 0; i < 3; i++) {
    final p = g.tray[i];
    if (p == null) continue;
    for (var r = 0; r <= boardSize - p.shape.rows; r++) {
      for (var c = 0; c <= boardSize - p.shape.cols; c++) {
        if (!g.canPlace(p.shape, r, c)) continue;
        final pc = g.previewClears(p.shape, r, c);
        final lines = pc.rows.length + pc.cols.length;
        // Prefer clears, then keeping the board open.
        final s = lines * 10.0 - r * 0.1 - c * 0.05 + p.shape.cells.length * 0.3;
        if (s > bestScore) {
          bestScore = s;
          best = (i, r, c);
        }
      }
    }
  }
  if (best == null) return false;
  g.place(best.$1, best.$2, best.$3);
  return true;
}

void main(List<String> args) {
  final games = args.isNotEmpty ? int.parse(args[0]) : 200;
  final mode = args.length > 1 ? GameMode.values.byName(args[1]) : GameMode.classic;
  var melted = 0, doused = 0, spreads = 0;
  final rnd = Random(7);
  var record = 0, records = 0;
  final scores = <int>[];
  final moves = <int>[];
  final goalHits = <Goal, int>{};
  final goalSeen = <Goal, int>{};
  for (var k = 0; k < games; k++) {
    final g = GameState(rng: Random(rnd.nextInt(1 << 30)), best: record, mode: mode);
    var m = 0;
    while (!g.gameOver && m < 3000) {
      final fires = g.burningCount;
      if (!_move(g)) break;
      if (g.burningCount > fires) spreads++;
      m++;
    }
    melted += g.thawedTotal;
    doused += g.dousedTotal;
    for (final goal in g.goals) {
      goalSeen[goal] = (goalSeen[goal] ?? 0) + 1;
      if (g.goalsDone.contains(goal)) goalHits[goal] = (goalHits[goal] ?? 0) + 1;
    }
    if (g.score > record) {
      if (record > 0) records++;
      record = g.score;
    }
    scores.add(g.score);
    moves.add(m);
  }
  scores.sort();
  final avg = scores.reduce((a, b) => a + b) / games;
  print('games: $games  mode: ${mode.name}');
  if (mode == GameMode.heat) {
    print(
      'per game: ice melted ${(melted / games).toStringAsFixed(1)}  fires out ${(doused / games).toStringAsFixed(1)}  fire jumps ${(spreads / games).toStringAsFixed(1)}',
    );
  }
  print(
    'avg score: ${avg.round()}  median: ${scores[games ~/ 2]}  p10: ${scores[games ~/ 10]}  p90: ${scores[games * 9 ~/ 10]}',
  );
  print('avg moves: ${(moves.reduce((a, b) => a + b) / games).round()}');
  print(
    'under 800: ${scores.where((s) => s < 800).length}  800-3000: ${scores.where((s) => s >= 800 && s < 3000).length}  3000+: ${scores.where((s) => s >= 3000).length}',
  );
  print('records broken: $records  final record: $record');
  for (final goal in Goal.values) {
    print('goal ${goal.name}: ${goalHits[goal] ?? 0}/${goalSeen[goal] ?? 0}');
  }
}

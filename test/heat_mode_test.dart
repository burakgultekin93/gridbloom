import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:blazegrid/game/game_state.dart';
import 'package:blazegrid/game/pieces.dart';

/// An empty heat board with no starting ice, so each test sets its own.
GameState _heat(int seed) {
  final g = GameState(rng: Random(seed), mode: GameMode.heat);
  for (var r = 0; r < boardSize; r++) {
    for (var c = 0; c < boardSize; c++) {
      g.board[r][c] = -1;
      g.ice[r][c] = 0;
      g.fuse[r][c] = 0;
    }
  }
  g.goals.clear();
  g.movesToWave = 99; // no wave unless a test wants one
  return g;
}

void _ice(GameState g, int r, int c, [int layers = 1]) {
  g.board[r][c] = frozenCell;
  g.ice[r][c] = layers;
}

void main() {
  test('heat game starts with spread-out ice; classic has none', () {
    final g = GameState(rng: Random(1), mode: GameMode.heat);
    expect(g.iceCount, 4);
    final rows = <int>{}, cols = <int>{};
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        if (g.board[r][c] == frozenCell) {
          rows.add(r);
          cols.add(c);
        }
      }
    }
    expect(rows.length, 4);
    expect(cols.length, 4);
    expect(GameState(rng: Random(1)).iceCount, 0);
  });

  test('pieces cannot go on ice', () {
    final g = _heat(2);
    _ice(g, 3, 3);
    expect(g.canPlace(piecesById['dot']!, 3, 3), isFalse);
    expect(g.canPlace(piecesById['dot']!, 3, 4), isTrue);
  });

  test('ice counts as filled for a line, cracks, and stays until it melts', () {
    final g = _heat(3);
    _ice(g, 0, 0, 2);
    g.board[5][5] = 1;
    for (var c = 1; c < 7; c++) {
      g.board[0][c] = 1;
    }
    g.tray[0] = TrayPiece(piecesById['dot']!, 1);
    final r = g.place(0, 0, 7)!;
    expect(r.linesCleared, 1);
    expect(r.iceHits, [(0, 0, IceHit.cracked)]);
    expect(g.board[0][0], frozenCell);
    expect(g.ice[0][0], 1);
    expect(r.clearedCells.length, 7); // the ice is not counted as a cleared block
  });

  test('a clear next to ice melts a single layer', () {
    final g = _heat(4);
    _ice(g, 1, 4);
    g.board[6][6] = 1;
    for (var c = 0; c < 7; c++) {
      g.board[0][c] = 1;
    }
    g.tray[0] = TrayPiece(piecesById['dot']!, 1);
    final r = g.place(0, 0, 7)!;
    expect(r.iceHits, [(1, 4, IceHit.melted)]);
    expect(g.board[1][4], -1);
    expect(g.thawedTotal, 1);
    expect(r.heatBonus, meltPoints);
  });

  test('a hot streak melts thick ice in one go', () {
    final g = _heat(5);
    g.streak = 3;
    _ice(g, 1, 2, 2);
    g.board[6][6] = 1;
    for (var c = 0; c < 7; c++) {
      g.board[0][c] = 1;
    }
    g.tray[0] = TrayPiece(piecesById['dot']!, 1);
    final r = g.place(0, 0, 7)!;
    expect(r.hotMelt, isTrue);
    expect(r.iceHits, [(1, 2, IceHit.melted)]);
  });

  test('clearing a burning block puts it out', () {
    final g = _heat(6);
    g.board[6][6] = 1;
    for (var c = 0; c < 7; c++) {
      g.board[0][c] = 1;
    }
    g.fuse[0][3] = 2;
    g.tray[0] = TrayPiece(piecesById['dot']!, 1);
    final r = g.place(0, 0, 7)!;
    expect(r.doused, [(0, 3)]);
    expect(g.fuse[0][3], 0);
    expect(g.dousedTotal, 1);
    expect(r.heatBonus, dousePoints);
  });

  test('fire spreads when its fuse runs out and the old block burns out', () {
    final g = _heat(7);
    g.board[4][4] = 2;
    g.fuse[4][4] = 1;
    g.tray[0] = TrayPiece(piecesById['dot']!, 1);
    final r = g.place(0, 0, 0)!;
    expect(r.spread.length, 1);
    final (from, (tr, tc)) = r.spread.single;
    expect(from, (4, 4));
    expect((tr - 4).abs() + (tc - 4).abs(), 1);
    expect(g.fuse[4][4], 0);
    expect(g.board[4][4], 2); // burnt out, still a block
    expect(g.fuse[tr][tc], g.config.heatFuse);
    expect(g.board[tr][tc], 2); // the empty cell filled with a burning block
  });

  test('fire that jumps onto ice dies out in steam', () {
    final g = _heat(8);
    g.board[4][4] = 2;
    g.fuse[4][4] = 1;
    for (final (r, c) in [(3, 4), (5, 4), (4, 3), (4, 5)]) {
      _ice(g, r, c);
    }
    g.tray[0] = TrayPiece(piecesById['dot']!, 1);
    final r = g.place(0, 0, 0)!;
    expect(r.spread, isEmpty);
    expect(r.steam.length, 1);
    expect(g.burningCount, 0);
    expect(g.iceCount, 3);
  });

  test('waves take turns: ice first, then fire', () {
    final g = _heat(9);
    g.board[7][7] = 3;
    g.movesToWave = 1;
    g.tray[0] = TrayPiece(piecesById['dot']!, 1);
    g.tray[1] = TrayPiece(piecesById['dot']!, 1);
    g.tray[2] = TrayPiece(piecesById['dot']!, 1);
    final a = g.place(0, 0, 0)!;
    expect(a.newIce.length, 1);
    expect(a.ignited, isEmpty);
    expect(g.movesToWave, g.config.heatWaveEvery);
    g.movesToWave = 1;
    final b = g.place(1, 0, 2)!;
    expect(b.ignited.length, 1);
    expect(g.burningCount, 1);
  });

  test('heat goals count melted ice and fires put out', () {
    final g = _heat(10);
    g.goals.addAll([Goal.douse2, Goal.thaw5, Goal.streak5]);
    g.dousedTotal = 1;
    g.board[6][6] = 1;
    for (var c = 0; c < 7; c++) {
      g.board[0][c] = 1;
    }
    g.fuse[0][1] = 3;
    g.tray[0] = TrayPiece(piecesById['dot']!, 1);
    final r = g.place(0, 0, 7)!;
    expect(r.goalsDone, [Goal.douse2]);
  });

  test('save and load keeps ice, fire and the wave clock', () {
    final g = _heat(11);
    _ice(g, 2, 2, 2);
    g.board[5][5] = 4;
    g.fuse[5][5] = 3;
    g.movesToWave = 2;
    g.waves = 3;
    g.thawedTotal = 7;
    final copy = GameState.fromJson(g.toJson())!;
    expect(copy.mode, GameMode.heat);
    expect(copy.board[2][2], frozenCell);
    expect(copy.ice[2][2], 2);
    expect(copy.fuse[5][5], 3);
    expect(copy.movesToWave, 2);
    expect(copy.nextWaveIsFire, isTrue);
    expect(copy.thawedTotal, 7);
    expect(copy.iceCount, 1);
  });

  test('a 1.0 classic save still loads as classic', () {
    final j = GameState(rng: Random(12)).toJson()..remove('mode');
    final copy = GameState.fromJson(j)!;
    expect(copy.mode, GameMode.classic);
    expect(copy.iceCount, 0);
  });
}

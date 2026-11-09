import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:blazegrid/game/game_state.dart';
import 'package:blazegrid/game/pieces.dart';

void main() {
  test('new game has 3 pieces and an empty board', () {
    final g = GameState(rng: Random(1));
    expect(g.tray.every((p) => p != null), isTrue);
    expect(g.board.expand((r) => r).every((v) => v == -1), isTrue);
  });

  test('filling a row clears it and scores', () {
    final g = GameState(rng: Random(2));
    for (var c = 0; c < 7; c++) {
      g.board[0][c] = 0;
    }
    g.tray[0] = TrayPiece(piecesById['dot']!, 1);
    final r = g.place(0, 0, 7)!;
    expect(r.linesCleared, 1);
    expect(r.points, 1 + 10 + 300); // the board is empty again
    expect(g.board[0].every((v) => v == -1), isTrue);
    expect(r.skinChanged, isTrue);
    expect(g.skin, 1);
    expect(r.clearedRows, [0]);
    expect(r.placedCells, [(0, 7)]);
  });

  test('row and column together count as 2 lines', () {
    final g = GameState(rng: Random(3));
    g.goals.clear(); // no goal bonus in this scoring check
    for (var i = 1; i < 8; i++) {
      g.board[0][i] = 0;
      g.board[i][0] = 0;
    }
    g.board[5][5] = 2; // keep the board from emptying
    g.tray[0] = TrayPiece(piecesById['dot']!, 1);
    final r = g.place(0, 0, 0)!;
    expect(r.linesCleared, 2);
    expect(r.points, 1 + 30);
    expect(r.skinChanged, isFalse);
    expect(g.skin, 0);
  });

  test('streak multiplies and resets after 3 non-clearing moves', () {
    expect(GameState.linePoints(4), 85);
    final g = GameState(rng: Random(4));
    g.streak = 1;
    g.movesSinceClear = 2;
    g.tray[0] = TrayPiece(piecesById['dot']!, 1);
    g.place(0, 4, 4);
    expect(g.streak, 0);
  });

  test('illegal placement is rejected', () {
    final g = GameState(rng: Random(5));
    g.tray[0] = TrayPiece(piecesById['i5h']!, 1);
    expect(g.place(0, 0, 4), isNull);
  });

  test('game is over when no tray piece fits', () {
    final g = GameState(rng: Random(6));
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        g.board[r][c] = (r + c) % 2 == 0 ? 0 : -1;
      }
    }
    g.tray[0] = TrayPiece(piecesById['dot']!, 0);
    g.tray[1] = TrayPiece(piecesById['o3']!, 0);
    g.tray[2] = TrayPiece(piecesById['o3']!, 0);
    g.place(0, 0, 1);
    expect(g.gameOver, isTrue);
  });

  test('save and load keeps the game', () {
    final g = GameState(rng: Random(7));
    g.board[3][3] = 2;
    g.score = 120;
    g.skin = 2;
    final copy = GameState.fromJson(g.toJson())!;
    expect(copy.board[3][3], 2);
    expect(copy.score, 120);
    expect(copy.skin, 2);
    expect(copy.tray[0]!.shape.id, g.tray[0]!.shape.id);
  });

  test('heat rises with the streak and cools between clears', () {
    final g = GameState(rng: Random(8));
    expect(g.heat, 0);
    g.streak = 3;
    expect(g.heat, 0.5);
    g.movesSinceClear = 2;
    expect(g.heat, 0.25);
    g.streak = 9;
    g.movesSinceClear = 0;
    expect(g.heat, 1);
  });

  test('warm-up trays have no large pieces and always fit together', () {
    for (var seed = 0; seed < 40; seed++) {
      final g = GameState(rng: Random(seed));
      for (final p in g.tray) {
        expect(p!.shape.size, isNot(PieceSize.large));
      }
    }
  });

  test('quiet help: warm-up and record chase get assist, normal play does not', () {
    final g = GameState(rng: Random(1), best: 5000);
    expect(g.assist, greaterThan(0.9));
    g.score = 2000;
    expect(g.assist, 0);
    g.score = 4200; // within 80% of the record
    expect(g.assist, greaterThanOrEqualTo(0.6));
    g.best = 50000; // very high records get no help
    g.score = 45000;
    expect(g.assist, 0);
  });

  test('finishing a mini goal adds its bonus once', () {
    final g = GameState(rng: Random(2));
    g.goals
      ..clear()
      ..addAll([Goal.double, Goal.lines10, Goal.triple]);
    g.board[5][5] = 1; // so the board is not fully cleared
    for (var c = 0; c < boardSize; c++) {
      if (c != 0) {
        g.board[0][c] = 1;
        g.board[1][c] = 1;
      }
    }
    g.tray[0] = TrayPiece(piecesById['i2v']!, 0);
    final r = g.place(0, 0, 0)!;
    expect(r.linesCleared, 2);
    expect(r.goalsDone, [Goal.double]);
    expect(g.goalsDone, {Goal.double});
    expect(r.points, 2 + 30 + 100);
  });

  test('save and load keeps goals and record', () {
    final g = GameState(rng: Random(3), best: 900);
    g.goalsDone.add(g.goals.first);
    final copy = GameState.fromJson(g.toJson())!;
    expect(copy.goals, g.goals);
    expect(copy.goalsDone, g.goalsDone);
    expect(copy.best, 900);
  });
}

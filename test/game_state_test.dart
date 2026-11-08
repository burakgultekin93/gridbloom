import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gridbloom/game/game_state.dart';
import 'package:gridbloom/game/pieces.dart';

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
  });

  test('row and column together count as 2 lines', () {
    final g = GameState(rng: Random(3));
    for (var i = 1; i < 8; i++) {
      g.board[0][i] = 0;
      g.board[i][0] = 0;
    }
    g.board[5][5] = 2; // keep the board from emptying
    g.tray[0] = TrayPiece(piecesById['dot']!, 1);
    final r = g.place(0, 0, 0)!;
    expect(r.linesCleared, 2);
    expect(r.points, 1 + 30);
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
    final copy = GameState.fromJson(g.toJson())!;
    expect(copy.board[3][3], 2);
    expect(copy.score, 120);
    expect(copy.tray[0]!.shape.id, g.tray[0]!.shape.id);
  });
}

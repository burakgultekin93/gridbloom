/// Piece definitions for Blazegrid.
///
/// Pieces cannot be rotated in play, so every orientation is its own shape.
library;

enum PieceSize { small, medium, large }

class Cell {
  final int r;
  final int c;
  const Cell(this.r, this.c);
}

class PieceShape {
  final String id;
  final List<Cell> cells;
  final PieceSize size;
  const PieceShape(this.id, this.cells, this.size);

  int get rows => cells.map((e) => e.r).reduce((a, b) => a > b ? a : b) + 1;
  int get cols => cells.map((e) => e.c).reduce((a, b) => a > b ? a : b) + 1;
}

/// Builds a shape from an ASCII pattern, where `#` marks a filled cell.
PieceShape _p(String id, PieceSize size, List<String> rows) {
  final cells = <Cell>[];
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < rows[r].length; c++) {
      if (rows[r][c] == '#') cells.add(Cell(r, c));
    }
  }
  return PieceShape(id, cells, size);
}

const _s = PieceSize.small, _m = PieceSize.medium, _l = PieceSize.large;

final List<PieceShape> allPieces = [
  // Small
  _p('dot', _s, ['#']),
  _p('i2h', _s, ['##']),
  _p('i2v', _s, ['#', '#']),
  _p('i3h', _s, ['###']),
  _p('i3v', _s, ['#', '#', '#']),
  _p('c3a', _s, ['##', '#.']),
  _p('c3b', _s, ['##', '.#']),
  _p('c3c', _s, ['#.', '##']),
  _p('c3d', _s, ['.#', '##']),
  // Medium
  _p('o2', _m, ['##', '##']),
  _p('i4h', _m, ['####']),
  _p('i4v', _m, ['#', '#', '#', '#']),
  _p('l4a', _m, ['#.', '#.', '##']),
  _p('l4b', _m, ['###', '#..']),
  _p('l4c', _m, ['##', '.#', '.#']),
  _p('l4d', _m, ['..#', '###']),
  _p('j4a', _m, ['.#', '.#', '##']),
  _p('j4b', _m, ['#..', '###']),
  _p('j4c', _m, ['##', '#.', '#.']),
  _p('j4d', _m, ['###', '..#']),
  _p('t4a', _m, ['###', '.#.']),
  _p('t4b', _m, ['.#', '##', '.#']),
  _p('t4c', _m, ['.#.', '###']),
  _p('t4d', _m, ['#.', '##', '#.']),
  _p('s4h', _m, ['.##', '##.']),
  _p('s4v', _m, ['#.', '##', '.#']),
  _p('z4h', _m, ['##.', '.##']),
  _p('z4v', _m, ['.#', '##', '#.']),
  // Large
  _p('i5h', _l, ['#####']),
  _p('i5v', _l, ['#', '#', '#', '#', '#']),
  _p('o3', _l, ['###', '###', '###']),
  _p('r23', _l, ['###', '###']),
  _p('r32', _l, ['##', '##', '##']),
  _p('bl_a', _l, ['#..', '#..', '###']),
  _p('bl_b', _l, ['###', '#..', '#..']),
  _p('bl_c', _l, ['###', '..#', '..#']),
  _p('bl_d', _l, ['..#', '..#', '###']),
];

final Map<String, PieceShape> piecesById = {for (final p in allPieces) p.id: p};

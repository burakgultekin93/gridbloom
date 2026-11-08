import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../game/game_state.dart';
import '../services/monetization.dart';
import '../services/storage.dart';
import 'painters.dart';
import 'palette.dart';

class GameScreen extends StatefulWidget {
  final GameState? resume;
  const GameScreen({super.key, this.resume});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late GameState game;
  final _stackKey = GlobalKey();
  final _boardKey = GlobalKey();
  late final Ticker _ticker;
  final List<Bloom> _blooms = [];
  DateTime _now = DateTime.now();

  int? _dragIndex;
  Offset _dragPos = Offset.zero; // in stack coordinates
  int _ghostRow = 0, _ghostCol = 0;
  bool _ghostValid = false;
  List<int> _clearRows = const [], _clearCols = const [];

  String? _toast;
  int _toastId = 0;
  late int _best;
  bool _newBest = false;

  @override
  void initState() {
    super.initState();
    game = widget.resume ?? GameState();
    _best = Storage.best;
    _ticker = createTicker((_) {
      _now = DateTime.now();
      _blooms.removeWhere((b) => _now.difference(b.start) > Bloom.duration);
      if (_blooms.isEmpty) _ticker.stop();
      setState(() {});
    });
    if (!Storage.tutorialSeen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorial());
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double get _cell {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    return box == null ? 40 : box.size.width / boardSize;
  }

  Offset get _boardOrigin {
    final board = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (board == null || stack == null) return Offset.zero;
    return stack.globalToLocal(board.localToGlobal(Offset.zero));
  }

  /// Top-left of the dragged piece: centred on the finger, lifted above it
  /// so the player can see where it lands.
  Offset _pieceTopLeft(TrayPiece p) {
    final cell = _cell;
    return _dragPos - Offset(p.shape.cols * cell / 2, p.shape.rows * cell + cell * 1.2);
  }

  Offset _toStack(Offset global) {
    final stack = _stackKey.currentContext!.findRenderObject() as RenderBox;
    return stack.globalToLocal(global);
  }

  void _onDragStart(int i, Offset global) {
    if (game.tray[i] == null || game.gameOver) return;
    setState(() {
      _dragIndex = i;
      _dragPos = _toStack(global);
    });
    _updateGhost();
  }

  void _onDragUpdate(Offset global) {
    if (_dragIndex == null) return;
    _dragPos = _toStack(global);
    _updateGhost();
  }

  void _updateGhost() {
    final p = game.tray[_dragIndex!]!;
    final rel = _pieceTopLeft(p) - _boardOrigin;
    final cell = _cell;
    final row = (rel.dy / cell).round(), col = (rel.dx / cell).round();
    final valid = game.canPlace(p.shape, row, col);
    setState(() {
      _ghostRow = row;
      _ghostCol = col;
      _ghostValid = valid;
      if (valid) {
        final clears = game.previewClears(p.shape, row, col);
        _clearRows = clears.rows;
        _clearCols = clears.cols;
      } else {
        _clearRows = const [];
        _clearCols = const [];
      }
    });
  }

  void _onDragEnd() {
    final i = _dragIndex;
    if (i == null) return;
    MoveResult? result;
    if (_ghostValid) result = game.place(i, _ghostRow, _ghostCol);
    setState(() {
      _dragIndex = null;
      _ghostValid = false;
      _clearRows = const [];
      _clearCols = const [];
    });
    if (result != null) _afterMove(result);
  }

  void _afterMove(MoveResult r) {
    if (Storage.haptics) {
      r.linesCleared > 0 ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
    }
    if (r.clearedCells.isNotEmpty) {
      final start = DateTime.now();
      for (final (row, col, color) in r.clearedCells) {
        // Stagger flowers outward a little for a ripple feel.
        _blooms.add(Bloom(row, col, color, start.add(Duration(milliseconds: ((row + col) % 4) * 40))));
      }
      if (!_ticker.isActive) _ticker.start();
    }
    if (r.boardCleared) {
      _showToast('Bahçe temiz! +300');
    } else if (r.linesCleared >= 2 || r.multiplier >= 2) {
      final parts = <String>[];
      if (r.linesCleared >= 2) parts.add('${r.linesCleared} çizgi');
      if (r.multiplier >= 2) parts.add('seri x${r.multiplier}');
      _showToast('${parts.join(' · ')}  +${r.points}');
    }
    if (game.score > _best) {
      _best = game.score;
      _newBest = true;
      Storage.best = _best;
    }
    if (game.gameOver) {
      Storage.clearSavedGame();
      Storage.gamesPlayed = Storage.gamesPlayed + 1;
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() {});
      });
    } else {
      Storage.saveGame(game);
    }
  }

  void _showToast(String text) {
    final id = ++_toastId;
    setState(() => _toast = text);
    Timer(const Duration(milliseconds: 1400), () {
      if (mounted && id == _toastId) setState(() => _toast = null);
    });
  }

  void _restart() {
    Storage.clearSavedGame();
    setState(() {
      game = GameState();
      _newBest = false;
      _blooms.clear();
    });
  }

  Future<void> _showTutorial() async {
    const steps = [
      ('Parçayı sürükle', 'Alttaki 3 parçadan birini tut ve bahçeye sürükle. Parçalar döndürülemez.'),
      ('Çizgiyi doldur', 'Bir satır ya da sütun tamamen dolunca çiçek açarak temizlenir.'),
      ('Seriyi sürdür', 'Aynı anda birden fazla çizgi temizle ve art arda temizleyerek puanını katla.'),
    ];
    var i = 0;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: Palette.background,
          title: Text(steps[i].$1, style: const TextStyle(color: Palette.soil, fontWeight: FontWeight.w700)),
          content: Text(steps[i].$2, style: const TextStyle(color: Palette.soil, fontSize: 16)),
          actions: [
            Text('${i + 1}/3  ', style: const TextStyle(color: Palette.soilLight)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Palette.leaf),
              onPressed: () {
                if (i < steps.length - 1) {
                  set(() => i++);
                } else {
                  Navigator.pop(ctx);
                }
              },
              child: Text(i < steps.length - 1 ? 'İleri' : 'Başla'),
            ),
          ],
        ),
      ),
    );
    Storage.tutorialSeen = true;
  }

  void _pause() {
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: Palette.background,
        title: const Text('Duraklatıldı', style: TextStyle(color: Palette.soil, fontWeight: FontWeight.w700)),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx), child: const Text('Devam et')),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _restart();
            },
            child: const Text('Yeniden başla'),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Ana menü'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dragging = _dragIndex != null ? game.tray[_dragIndex!] : null;
    final showGameOver = game.gameOver && _blooms.isEmpty;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final boardSide = (constraints.maxWidth - 32).clamp(200.0, constraints.maxHeight * 0.58);
          final cell = boardSide / boardSize;
          return Stack(
            key: _stackKey,
            children: [
              Column(
                children: [
                  _topBar(),
                  const Spacer(),
                  Center(
                    child: SizedBox(
                      key: _boardKey,
                      width: boardSide,
                      height: boardSide,
                      child: CustomPaint(
                        painter: BoardPainter(
                          game: game,
                          ghost: _ghostValid ? dragging?.shape : null,
                          ghostRow: _ghostRow,
                          ghostCol: _ghostCol,
                          ghostColor: dragging?.color ?? 0,
                          clearRows: _clearRows,
                          clearCols: _clearCols,
                          blooms: _blooms,
                          now: _now,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  _tray(cell * 0.55),
                  const SizedBox(height: 24),
                ],
              ),
              if (_toast != null)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 72,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(color: Palette.leaf, borderRadius: BorderRadius.circular(20)),
                        child: Text(_toast!,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ),
              if (dragging != null)
                Positioned(
                  left: _pieceTopLeft(dragging).dx,
                  top: _pieceTopLeft(dragging).dy,
                  child: IgnorePointer(
                    child: CustomPaint(
                      size: Size(dragging.shape.cols * cell, dragging.shape.rows * cell),
                      painter: PiecePainter(dragging.shape, dragging.color, cell, opacity: 0.95),
                    ),
                  ),
                ),
              if (showGameOver) _gameOverOverlay(),
            ],
          );
        }),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('REKOR', style: TextStyle(color: Palette.soilLight, fontSize: 12, letterSpacing: 1.2)),
            Text('$_best', style: const TextStyle(color: Palette.soil, fontSize: 18, fontWeight: FontWeight.w700)),
          ]),
          const Spacer(),
          Text('${game.score}',
              style: const TextStyle(color: Palette.soil, fontSize: 40, fontWeight: FontWeight.w800)),
          const Spacer(),
          IconButton(
            onPressed: _pause,
            icon: const Icon(Icons.pause_rounded, color: Palette.soil, size: 30),
            tooltip: 'Duraklat',
          ),
        ],
      ),
    );
  }

  Widget _tray(double cell) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: List.generate(3, (i) {
          final p = game.tray[i];
          final fits = p != null && game.fitsAnywhere(p.shape);
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.down,
              onPanDown: (d) => _onDragStart(i, d.globalPosition),
              onPanUpdate: (d) => _onDragUpdate(d.globalPosition),
              onPanEnd: (_) => _onDragEnd(),
              onPanCancel: _onDragEnd,
              child: SizedBox(
                height: cell * 5.4,
                child: p == null || _dragIndex == i
                    ? null
                    : CustomPaint(painter: PiecePainter(p.shape, p.color, cell, opacity: fits ? 1 : 0.35)),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _gameOverOverlay() {
    return Positioned.fill(
      child: Container(
        color: Palette.soil.withValues(alpha: 0.55),
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Palette.background, borderRadius: BorderRadius.circular(24)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_newBest ? 'Yeni rekor!' : 'Yer kalmadı',
                style: const TextStyle(color: Palette.soil, fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text('${game.score}', style: const TextStyle(color: Palette.leaf, fontSize: 48, fontWeight: FontWeight.w800)),
            Text('Rekor: $_best', style: const TextStyle(color: Palette.soilLight, fontSize: 16)),
            const SizedBox(height: 20),
            if (Monetization.canOfferContinue) ...[
              // Step 4: rewarded ad, continue once with 3 new pieces.
              OutlinedButton(onPressed: () {}, child: const Text('Reklam izle, devam et')),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Palette.leaf, padding: const EdgeInsets.all(14)),
                onPressed: _restart,
                child: const Text('Tekrar oyna', style: TextStyle(fontSize: 18)),
              ),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ana menü')),
          ]),
        ),
      ),
    );
  }
}

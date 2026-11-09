import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../game/game_state.dart';
import '../services/monetization.dart';
import '../services/photo_store.dart';
import '../services/storage.dart';
import 'bursts.dart';
import 'effects.dart';
import 'painters.dart';
import 'palette.dart';
import 'skins.dart';

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
  final BoardFx _fx = BoardFx();
  DateTime _now = DateTime.now();

  int? _dragIndex;
  Offset _dragPos = Offset.zero; // in stack coordinates
  int _ghostRow = 0, _ghostCol = 0;
  bool _ghostValid = false;
  List<int> _clearRows = const [], _clearCols = const [];

  // Effects clock and heat.
  Duration _elapsed = Duration.zero;
  Duration _lastTick = Duration.zero;
  double _heat = 0; // shown heat, eases toward game.heat
  DateTime? _blazeStart;
  static const _blazeLength = Duration(milliseconds: 3200);

  // Praise text.
  String? _praise;
  String? _praiseSub;
  DateTime? _praiseStart;
  static const _praiseLength = Duration(milliseconds: 1300);
  late int _best;
  bool _newBest = false;

  @override
  void initState() {
    super.initState();
    game = widget.resume ?? GameState();
    _best = Storage.best;
    _heat = game.heat;
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
      _lastTick = elapsed;
      _elapsed = elapsed;
      _now = DateTime.now();
      _blooms.removeWhere((b) => _now.difference(b.start) > Bloom.duration);
      _fx.prune(_now);
      _heat += (game.heat - _heat) * min(1.0, dt * 2.5);
      setState(() {});
    })..start();
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
    // A soft tick each time the piece snaps onto a new spot.
    if (valid && Storage.haptics && (!_ghostValid || row != _ghostRow || col != _ghostCol)) {
      HapticFeedback.selectionClick();
    }
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
    _haptics(r);
    final now = DateTime.now();
    _fx.flashes.add(PlaceFlash(r.placedCells, now));
    _fx.glint = now;
    for (final row in r.clearedRows) {
      _fx.beams.add(LineBeam(true, row, now));
    }
    for (final col in r.clearedCols) {
      _fx.beams.add(LineBeam(false, col, now));
    }
    _explode(r, now);
    if (r.clearedCells.isNotEmpty) {
      final start = DateTime.now();
      for (final (row, col, color) in r.clearedCells) {
        // Stagger flowers outward a little for a ripple feel.
        _blooms.add(Bloom(row, col, color, start.add(Duration(milliseconds: ((row + col) % 4) * 40)), heat: game.heat));
      }
      if (!_ticker.isActive) _ticker.start();
    }
    if (r.boardCleared) {
      _blazeStart = DateTime.now();
    }
    final praise = praiseFor(r);
    if (praise != null) {
      final parts = <String>['+${r.points}'];
      if (r.linesCleared >= 2) parts.add('${r.linesCleared} çizgi');
      if (r.multiplier >= 2) parts.add('seri x${r.multiplier}');
      if (r.skinChanged) parts.add('yeni görünüm: ${skins[game.skin].name}');
      setState(() {
        _praise = praise;
        _praiseSub = parts.join(' · ');
        _praiseStart = DateTime.now();
      });
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

  /// Ice explosions while the streak is cold, fire once it heats up.
  /// A full board clear sets off both at once.
  void _explode(MoveResult r, DateTime now) {
    if (r.linesCleared == 0) return;
    final kind = game.heat >= 0.34 ? BurstKind.fire : BurstKind.ice;
    final rnd = Random();
    final big = r.linesCleared >= 2;
    for (final (row, col, _) in r.clearedCells) {
      final delay = Duration(milliseconds: ((row + col) % 5) * 35);
      _fx.bursts.add(Burst(Offset(col + 0.5, row + 0.5), kind, big ? 0.9 : 0.6, now.add(delay), rnd.nextInt(1 << 30)));
    }
    for (final row in r.clearedRows) {
      _fx.bursts.add(
        Burst(Offset(boardSize / 2, row + 0.5), kind, 1.6 + 0.4 * r.linesCleared, now, rnd.nextInt(1 << 30)),
      );
    }
    for (final col in r.clearedCols) {
      _fx.bursts.add(
        Burst(Offset(col + 0.5, boardSize / 2), kind, 1.6 + 0.4 * r.linesCleared, now, rnd.nextInt(1 << 30)),
      );
    }
    const mid = Offset(boardSize / 2, boardSize / 2);
    if (r.boardCleared) {
      _fx.bursts.add(Burst(mid, BurstKind.ice, 5, now, rnd.nextInt(1 << 30)));
      _fx.bursts.add(Burst(mid, BurstKind.fire, 6, now.add(const Duration(milliseconds: 180)), rnd.nextInt(1 << 30)));
      _fx.shake(now, 0.35);
    } else if (r.linesCleared >= 3) {
      _fx.bursts.add(Burst(mid, kind, 3.5, now.add(const Duration(milliseconds: 90)), rnd.nextInt(1 << 30)));
      _fx.shake(now, 0.22);
    } else if (big) {
      _fx.shake(now, 0.12);
    }
  }

  /// Light vibration for every point scored, stronger for bigger moves.
  void _haptics(MoveResult r) {
    if (!Storage.haptics) return;
    if (r.boardCleared) {
      HapticFeedback.heavyImpact();
      for (var i = 1; i <= 3; i++) {
        Future.delayed(Duration(milliseconds: 110 * i), HapticFeedback.heavyImpact);
      }
    } else if (r.linesCleared >= 2) {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 90), HapticFeedback.mediumImpact);
    } else if (r.linesCleared == 1) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  double get _blaze {
    final start = _blazeStart;
    if (start == null) return 0;
    final t = _now.difference(start).inMilliseconds / _blazeLength.inMilliseconds;
    if (t >= 1) return 0;
    return t < 0.15 ? t / 0.15 : 1 - Curves.easeIn.transform((t - 0.15) / 0.85);
  }

  void _restart() {
    Storage.clearSavedGame();
    setState(() {
      game = GameState();
      _newBest = false;
      _blooms.clear();
      _fx.clear();
      _praise = null;
      _blazeStart = null;
    });
  }

  Future<void> _showTutorial() async {
    const steps = [
      ('Parçayı sürükle', 'Alttaki 3 parçadan birini tut ve tahtaya sürükle. Parçalar döndürülemez.'),
      ('Çizgiyi doldur', 'Bir satır ya da sütun tamamen dolunca çiçek açarak temizlenir.'),
      ('Seriyi sürdür', 'Aynı anda birden fazla çizgi temizle ve art arda temizleyerek puanını katla.'),
    ];
    var i = 0;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: Palette.panel,
          title: Text(
            steps[i].$1,
            style: const TextStyle(color: Palette.soil, fontWeight: FontWeight.w700),
          ),
          content: Text(steps[i].$2, style: const TextStyle(color: Palette.soil, fontSize: 16)),
          actions: [
            Text('${i + 1}/3  ', style: const TextStyle(color: Palette.soilLight)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Palette.leaf, foregroundColor: Colors.white),
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
        backgroundColor: Palette.panel,
        title: const Text(
          'Duraklatıldı',
          style: TextStyle(color: Palette.soil, fontWeight: FontWeight.w700),
        ),
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
    final blaze = _blaze;
    final shownHeat = max(_heat, blaze);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [heatTop(shownHeat), heatBottom(shownHeat)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: HeatEffectsPainter(heat: _heat, seconds: _elapsed.inMicroseconds / 1e6, blaze: blaze),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final boardSide = (constraints.maxWidth - 32).clamp(200.0, constraints.maxHeight * 0.58);
                  final cell = boardSide / boardSize;
                  return Stack(
                    key: _stackKey,
                    children: [
                      Column(
                        children: [
                          _topBar(shownHeat),
                          _heatMeter(shownHeat),
                          const Spacer(),
                          Center(
                            child: Transform.translate(
                              offset: _fx.shakeOffset(_now) * cell,
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
                                    skin: skins[game.skin],
                                    photo: PhotoStore.image.value,
                                    fx: _fx,
                                    pattern: BlockPattern.values[Storage.pattern],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          _tray(cell * 0.55),
                          const SizedBox(height: 24),
                        ],
                      ),
                      if (_praise != null) _praiseOverlay(boardSide),
                      if (dragging != null)
                        Positioned(
                          left: _pieceTopLeft(dragging).dx,
                          top: _pieceTopLeft(dragging).dy,
                          child: IgnorePointer(
                            child: CustomPaint(
                              size: Size(dragging.shape.cols * cell, dragging.shape.rows * cell),
                              painter: PiecePainter(
                                dragging.shape,
                                dragging.color,
                                cell,
                                opacity: 0.95,
                                skin: skins[game.skin],
                                pattern: BlockPattern.values[Storage.pattern],
                              ),
                            ),
                          ),
                        ),
                      if (showGameOver) _gameOverOverlay(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(double heat) {
    final ink = heatInk(heat);
    final soft = ink.withValues(alpha: 0.7);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('REKOR', style: TextStyle(color: soft, fontSize: 12, letterSpacing: 1.2)),
                Text(
                  '$_best',
                  style: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Spacer(),
          Column(
            children: [
              Text('KLASİK', style: TextStyle(color: soft, fontSize: 12, letterSpacing: 2)),
              Text(
                '${game.score}',
                style: TextStyle(color: ink, fontSize: 40, fontWeight: FontWeight.w800, height: 1.1),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 72,
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: _pause,
                icon: Icon(Icons.pause_rounded, color: ink, size: 30),
                tooltip: 'Duraklat',
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Streak thermometer: snowflake when cold, flame when hot.
  Widget _heatMeter(double heat) {
    final ink = heatInk(heat);
    final barColor = Color.lerp(const Color(0xFF6FB3E0), const Color(0xFFFF5A1F), heat)!;
    final label = game.streak >= 2 ? 'Seri x${game.streak} · ${heatLabel(heat)}' : heatLabel(heat);
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 6, 48, 0),
      child: Row(
        children: [
          Icon(heat < 0.35 ? Icons.ac_unit_rounded : Icons.local_fire_department_rounded, color: barColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Container(height: 10, color: ink.withValues(alpha: 0.15)),
                  FractionallySizedBox(
                    widthFactor: max(0.04, heat),
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF6FB3E0), barColor])),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _praiseOverlay(double boardSide) {
    final start = _praiseStart!;
    final t = _now.difference(start).inMilliseconds / _praiseLength.inMilliseconds;
    if (t >= 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _praiseStart == start) setState(() => _praise = null);
      });
      return const SizedBox.shrink();
    }
    final scale = Curves.elasticOut.transform(min(1.0, t * 2.2)) * 0.9 + 0.1;
    final opacity = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
    final rise = -24 * t;
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: const Alignment(0, -0.15),
          child: Transform.translate(
            offset: Offset(0, rise),
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: boardSide,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _praise!,
                          style: TextStyle(
                            fontSize: boardSide * 0.13,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: const [
                              Shadow(color: Color(0xCC8E1F12), offset: Offset(0, 3), blurRadius: 0),
                              Shadow(color: Color(0x66000000), offset: Offset(0, 6), blurRadius: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_praiseSub != null)
                      Text(
                        _praiseSub!,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFFE08A),
                          shadows: [Shadow(color: Color(0x99000000), offset: Offset(0, 2), blurRadius: 4)],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
                    : CustomPaint(
                        painter: PiecePainter(
                          p.shape,
                          p.color,
                          cell,
                          opacity: fits ? 1 : 0.35,
                          skin: skins[game.skin],
                          pattern: BlockPattern.values[Storage.pattern],
                        ),
                      ),
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
        color: Colors.black.withValues(alpha: 0.6),
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Palette.panel,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Palette.leaf.withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _newBest ? 'Yeni rekor!' : 'Yer kalmadı',
                style: const TextStyle(color: Palette.soil, fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                '${game.score}',
                style: const TextStyle(color: Palette.leaf, fontSize: 48, fontWeight: FontWeight.w800),
              ),
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
                  style: FilledButton.styleFrom(
                    backgroundColor: Palette.leaf,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(14),
                  ),
                  onPressed: _restart,
                  child: const Text('Tekrar oyna', style: TextStyle(fontSize: 18)),
                ),
              ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ana menü')),
            ],
          ),
        ),
      ),
    );
  }
}

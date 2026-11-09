import 'dart:math';

import 'package:flutter/material.dart';

/// Ice and fire explosions shown when lines clear.
///
/// A burst is drawn on the board canvas. Its particles are generated from a
/// fixed seed so that every frame shows the same particles further along.
enum BurstKind { ice, fire }

class Burst {
  /// Centre in cell units (column, row), e.g. (3.5, 2.5) is the centre of cell (2, 3).
  final Offset center;
  final BurstKind kind;

  /// 1 for a single cell, larger for line and board explosions.
  final double power;
  final DateTime start;
  final int seed;

  /// Half length of the cleared line in cell units, e.g. (4, 0) for a row.
  /// Chain pops run along it. Zero for round bursts.
  final Offset spread;

  /// Current combo streak: hotter streaks add more pops and rings.
  final int streak;
  Burst(this.center, this.kind, this.power, this.start, this.seed, {this.spread = Offset.zero, this.streak = 0});

  Duration get duration => Duration(milliseconds: (650 + 220 * min(power, 4) + (power >= 1.5 ? 200 : 0)).round());
}

const _iceColors = [Color(0xFFFFFFFF), Color(0xFFCFF1FF), Color(0xFF8FD8FF), Color(0xFF4FB2F0)];
const _fireColors = [Color(0xFFFFF1A8), Color(0xFFFFC23D), Color(0xFFFF7A1A), Color(0xFFE0301E)];

void paintBursts(Canvas canvas, double cell, List<Burst> bursts, DateTime now) {
  for (final b in bursts) {
    final t = now.difference(b.start).inMicroseconds / b.duration.inMicroseconds;
    if (t < 0 || t > 1) continue;
    if (b.power < 1) {
      _paintPop(canvas, cell, b, t);
    }
    if (b.kind == BurstKind.ice) {
      _paintIce(canvas, cell, b, t);
    } else {
      _paintFire(canvas, cell, b, t);
    }
    if (b.power >= 1.5) {
      _paintChain(canvas, cell, b, t);
    }
  }
}

void _shockwave(Canvas canvas, Offset c, double radius, double t, Color color, double cell) {
  final r = radius * Curves.easeOutCubic.transform(t);
  final a = (1 - t) * (1 - t);
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.35 * (1 - t) + 1
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.12)
      ..color = color.withValues(alpha: 0.85 * a),
  );
}

void _paintIce(Canvas canvas, double cell, Burst b, double t) {
  final rnd = Random(b.seed);
  final c = b.center * cell;
  final reach = cell * (1.2 + 0.9 * b.power);

  // Cold flash and frost ring.
  if (t < 0.35) {
    canvas.drawCircle(
      c,
      cell * (0.6 + 0.5 * b.power) * (0.6 + t),
      Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.6)
        ..color = const Color(0xFFE6F8FF).withValues(alpha: 0.9 * (1 - t / 0.35)),
    );
  }
  _shockwave(canvas, c, reach, t, const Color(0xFFBDEBFF), cell);
  if (b.power >= 1.5) {
    _rays(canvas, c, reach * 1.1, t, Random(b.seed + 7), _iceColors[1], cell, sharp: true);
    _frostCracks(canvas, c, reach, t, Random(b.seed + 3), cell);
    _starburst(canvas, c, cell * (0.55 + 0.32 * min(b.power, 5)), t, Random(b.seed + 1), _iceColors, ice: true);
  }
  if (b.power >= 3) {
    _bigFlake(canvas, c, reach * 0.75, t, cell);
  }

  // Ice shards fly out, spin and fall a little.
  final count = (10 + 7 * b.power).round();
  final ease = Curves.easeOutCubic.transform(t);
  final fade = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
  for (var i = 0; i < count; i++) {
    final angle = rnd.nextDouble() * 2 * pi;
    final dist = reach * (0.35 + rnd.nextDouble() * 0.75);
    final size = cell * (0.12 + rnd.nextDouble() * 0.2) * (0.7 + 0.3 * min(b.power, 3));
    final spin = (rnd.nextDouble() - 0.5) * 9;
    final color = _iceColors[rnd.nextInt(_iceColors.length)];
    final p = c + Offset(cos(angle), sin(angle)) * dist * ease + Offset(0, cell * 0.9 * t * t);
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(angle + spin * t);
    final shard = Path()
      ..moveTo(size * 1.3, 0)
      ..lineTo(0, size * 0.42)
      ..lineTo(-size * 0.7, 0)
      ..lineTo(0, -size * 0.42)
      ..close();
    canvas.drawPath(shard, Paint()..color = color.withValues(alpha: 0.95 * fade));
    canvas.drawLine(
      Offset(-size * 0.5, 0),
      Offset(size * 1.1, 0),
      Paint()
        ..strokeWidth = max(1, size * 0.12)
        ..color = Colors.white.withValues(alpha: 0.8 * fade),
    );
    canvas.restore();
  }

  // Snowflake sparkles that twinkle and drift.
  final flakes = (4 + 3 * b.power).round();
  for (var i = 0; i < flakes; i++) {
    final angle = rnd.nextDouble() * 2 * pi;
    final dist = reach * (0.2 + rnd.nextDouble() * 0.6);
    final s = cell * (0.12 + rnd.nextDouble() * 0.12);
    final p = c + Offset(cos(angle), sin(angle)) * dist * ease;
    final tw = (0.5 + 0.5 * sin(t * 30 + i)) * fade;
    final paint = Paint()
      ..strokeWidth = max(1, s * 0.22)
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: tw);
    for (var k = 0; k < 3; k++) {
      final a = k * pi / 3 + t * 2;
      final d = Offset(cos(a), sin(a)) * s;
      canvas.drawLine(p - d, p + d, paint);
    }
  }
}

void _paintFire(Canvas canvas, double cell, Burst b, double t) {
  final rnd = Random(b.seed);
  final c = b.center * cell;
  final reach = cell * (1.3 + 1.0 * b.power);

  // Fireball core.
  if (t < 0.45) {
    final k = 1 - t / 0.45;
    final r = cell * (0.5 + 0.55 * b.power) * (0.7 + t * 1.2);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.7)
        ..color = const Color(0xFFFF7A1A).withValues(alpha: 0.85 * k),
    );
    canvas.drawCircle(
      c,
      r * 0.55,
      Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.35)
        ..color = const Color(0xFFFFF1A8).withValues(alpha: 0.95 * k),
    );
  }
  _shockwave(canvas, c, reach, t, const Color(0xFFFFA23D), cell);
  if (b.power >= 1.5) {
    _rays(canvas, c, reach * 1.15, t, Random(b.seed + 7), _fireColors[1], cell, sharp: false);
    _starburst(canvas, c, cell * (0.6 + 0.35 * min(b.power, 5)), t, Random(b.seed + 1), _fireColors, ice: false);
    _sparks(canvas, c, reach, t, Random(b.seed + 5), b, cell);
  }
  if (b.power >= 3) {
    // A second, delayed ring for big blasts.
    if (t > 0.15) _shockwave(canvas, c, reach * 1.4, (t - 0.15) / 0.85, const Color(0xFFFFE08A), cell);
  }

  // Flame blobs and embers thrown outward, rising as they cool.
  final count = (12 + 8 * b.power).round();
  final ease = Curves.easeOutQuart.transform(t);
  for (var i = 0; i < count; i++) {
    final angle = rnd.nextDouble() * 2 * pi;
    final dist = reach * (0.3 + rnd.nextDouble() * 0.8);
    final life = 0.55 + rnd.nextDouble() * 0.45;
    final lt = min(1.0, t / life);
    if (lt >= 1) continue;
    final big = rnd.nextDouble() < 0.45;
    final p = c + Offset(cos(angle), sin(angle)) * dist * ease - Offset(0, cell * 0.8 * t * t);
    final colorT = min(0.999, lt * 1.3 + rnd.nextDouble() * 0.3);
    final color = _fireColors[(colorT * _fireColors.length).floor()];
    final a = 1 - lt;
    if (big) {
      final r = cell * (0.16 + rnd.nextDouble() * 0.18) * (1 - lt * 0.6) * (0.8 + 0.2 * min(b.power, 3));
      canvas.drawCircle(
        p,
        r * 1.8,
        Paint()
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r)
          ..color = color.withValues(alpha: 0.5 * a),
      );
      canvas.drawCircle(p, r, Paint()..color = color.withValues(alpha: 0.95 * a));
    } else {
      // Ember streak pointing along its flight.
      final dir = Offset(cos(angle), sin(angle) - 0.4 * t);
      final len = cell * 0.35 * (1 - lt);
      canvas.drawLine(
        p,
        p - dir * len,
        Paint()
          ..strokeWidth = max(1.5, cell * 0.07)
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: a),
      );
    }
  }

  // Smoke puffs late in the explosion.
  if (t > 0.35) {
    final st = (t - 0.35) / 0.65;
    final puffs = (3 + 2 * b.power).round();
    for (var i = 0; i < puffs; i++) {
      final angle = rnd.nextDouble() * 2 * pi;
      final p = c + Offset(cos(angle), sin(angle)) * reach * 0.45 * st - Offset(0, cell * 1.2 * st);
      canvas.drawCircle(
        p,
        cell * (0.3 + 0.4 * st),
        Paint()
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.3)
          ..color = const Color(0xFF5A4A44).withValues(alpha: 0.22 * (1 - st)),
      );
    }
  }
}

/// Elastic grow, then shrink and fade: the "pop" timing used by the cartoon
/// explosion shapes.
double _popScale(double t, {double grow = 0.22}) {
  if (t < grow) return Curves.easeOutBack.transform(t / grow);
  return 1 - Curves.easeInCubic.transform((t - grow) / (1 - grow));
}

/// A comic-book explosion: a jagged star that pops out with a bounce, in three
/// nested layers. Ice gets long crystal spikes, fire gets a lumpy fireball.
void _starburst(Canvas canvas, Offset c, double radius, double t, Random rnd, List<Color> colors, {required bool ice}) {
  if (t > 0.7) return;
  final k = _popScale(t / 0.7);
  if (k <= 0) return;
  final spikes = ice ? 8 : 11 + rnd.nextInt(4);
  final rot = rnd.nextDouble() * pi + t * (ice ? 0.6 : -0.9);
  final jitter = [for (var i = 0; i < spikes * 2; i++) rnd.nextDouble()];
  Path shape(double r) {
    final path = Path();
    for (var i = 0; i < spikes * 2; i++) {
      final a = rot + i * pi / spikes;
      final outer = i.isEven;
      final rr = ice
          ? (outer ? r * (i % 4 == 0 ? 1.0 : 0.72) : r * 0.32)
          : (outer ? r * (0.82 + 0.3 * jitter[i]) : r * (0.5 + 0.12 * jitter[i]));
      final p = c + Offset(cos(a), sin(a)) * rr;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  final alpha = t < 0.5 ? 1.0 : 1 - (t - 0.5) / 0.2;
  final layers = ice ? [colors[3], colors[2], colors[0]] : [colors[3], colors[2], colors[0]];
  final sizes = [1.0, 0.74, 0.44];
  for (var i = 0; i < 3; i++) {
    canvas.drawPath(
      shape(radius * k * sizes[i]),
      Paint()..color = layers[i].withValues(alpha: (i == 0 ? 0.75 : 0.92) * alpha),
    );
  }
  // Dark comic outline on the outer layer.
  canvas.drawPath(
    shape(radius * k),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, radius * 0.06)
      ..strokeJoin = StrokeJoin.round
      ..color = (ice ? const Color(0xFF0B2A4A) : const Color(0xFF3A0E06)).withValues(alpha: 0.5 * alpha),
  );
}

/// Light rays fanning out from the centre.
void _rays(
  Canvas canvas,
  Offset c,
  double reach,
  double t,
  Random rnd,
  Color color,
  double cell, {
  required bool sharp,
}) {
  if (t > 0.55) return;
  final lt = t / 0.55;
  final n = sharp ? 12 : 10;
  final a0 = rnd.nextDouble() * pi;
  final len = reach * Curves.easeOutCubic.transform(lt);
  final paint = Paint()..color = color.withValues(alpha: 0.4 * (1 - lt));
  for (var i = 0; i < n; i++) {
    final a = a0 + i * 2 * pi / n + (rnd.nextDouble() - 0.5) * 0.25;
    final w = (sharp ? 0.05 : 0.09) * (0.7 + rnd.nextDouble() * 0.6);
    final l = len * (0.7 + rnd.nextDouble() * 0.5);
    final path = Path()
      ..moveTo(c.dx + cos(a - w) * cell * 0.3, c.dy + sin(a - w) * cell * 0.3)
      ..lineTo(c.dx + cos(a) * l, c.dy + sin(a) * l)
      ..lineTo(c.dx + cos(a + w) * cell * 0.3, c.dy + sin(a + w) * cell * 0.3)
      ..close();
    canvas.drawPath(path, paint);
  }
}

/// Zig-zag frost cracks shooting out over the board.
void _frostCracks(Canvas canvas, Offset c, double reach, double t, Random rnd, double cell) {
  if (t > 0.6) return;
  final grow = Curves.easeOutExpo.transform(min(1.0, t / 0.18));
  final a = 1 - t / 0.6;
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(1, cell * 0.045)
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = Colors.white.withValues(alpha: 0.85 * a);
  for (var i = 0; i < 7; i++) {
    var ang = rnd.nextDouble() * 2 * pi;
    var p = c;
    final path = Path()..moveTo(p.dx, p.dy);
    final steps = 5;
    final segLen = reach * (0.7 + rnd.nextDouble() * 0.5) / steps * grow;
    for (var s = 0; s < steps; s++) {
      ang += (rnd.nextDouble() - 0.5) * 0.9;
      p += Offset(cos(ang), sin(ang)) * segLen;
      path.lineTo(p.dx, p.dy);
      if (rnd.nextDouble() < 0.35) {
        final ba = ang + (rnd.nextBool() ? 0.8 : -0.8);
        final q = p + Offset(cos(ba), sin(ba)) * segLen * 0.6;
        path
          ..lineTo(q.dx, q.dy)
          ..moveTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, paint);
  }
}

/// A giant six-armed snowflake that spins in and melts away.
void _bigFlake(Canvas canvas, Offset c, double r, double t, double cell) {
  if (t > 0.8) return;
  final k = _popScale(t / 0.8, grow: 0.3);
  if (k <= 0) return;
  final size = r * k;
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(2, cell * 0.12)
    ..strokeCap = StrokeCap.round
    ..color = Colors.white.withValues(alpha: 0.85 * (1 - t / 0.8));
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(t * 1.5);
  for (var i = 0; i < 6; i++) {
    canvas.drawLine(Offset.zero, Offset(size, 0), paint);
    for (final f in [0.45, 0.7]) {
      final base = Offset(size * f, 0);
      final l = size * (f == 0.45 ? 0.28 : 0.2);
      canvas.drawLine(base, base + Offset(cos(pi / 4), sin(pi / 4)) * l, paint);
      canvas.drawLine(base, base + Offset(cos(-pi / 4), sin(-pi / 4)) * l, paint);
    }
    canvas.rotate(pi / 3);
  }
  canvas.restore();
}

/// Bright sparks with streaking tails that arc up and fall with gravity.
void _sparks(Canvas canvas, Offset c, double reach, double t, Random rnd, Burst b, double cell) {
  final n = (10 + 6 * min(b.power, 5) + 3 * min(b.streak, 6)).round();
  for (var i = 0; i < n; i++) {
    final a = -pi / 2 + (rnd.nextDouble() - 0.5) * 2.6;
    final v = reach * (1.2 + rnd.nextDouble() * 1.6);
    final life = 0.6 + rnd.nextDouble() * 0.4;
    final color = _fireColors[rnd.nextInt(2)];
    if (t > life) continue;
    Offset at(double tt) => c + Offset(cos(a), sin(a)) * v * tt + Offset(0, cell * 9 * tt * tt);
    final p = at(t);
    final tail = at(max(0, t - 0.07));
    final fade = 1 - t / life;
    canvas.drawLine(
      tail,
      p,
      Paint()
        ..strokeWidth = max(1.5, cell * 0.08) * (0.5 + fade * 0.5)
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: fade),
    );
    canvas.drawCircle(p, max(1.2, cell * 0.06), Paint()..color = Colors.white.withValues(alpha: fade));
  }
}

/// Small pop for a single cleared cell: a ring that snaps out and a twinkle
/// star (ice) or a puff ball (fire).
void _paintPop(Canvas canvas, double cell, Burst b, double t) {
  if (t > 0.45) return;
  final c = b.center * cell;
  final lt = t / 0.45;
  final k = _popScale(lt, grow: 0.35);
  final ice = b.kind == BurstKind.ice;
  final color = ice ? _iceColors[1] : _fireColors[1];
  canvas.drawCircle(
    c,
    cell * (0.3 + 0.5 * Curves.easeOutCubic.transform(lt)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, cell * 0.08 * (1 - lt))
      ..color = color.withValues(alpha: 0.9 * (1 - lt)),
  );
  if (ice) {
    _twinkle(canvas, c, cell * 0.42 * k, Colors.white.withValues(alpha: 1 - lt), t * 3);
  } else {
    canvas.drawCircle(c, cell * 0.3 * k, Paint()..color = _fireColors[0].withValues(alpha: 1 - lt));
  }
}

/// A four-pointed sparkle star.
void _twinkle(Canvas canvas, Offset c, double r, Color color, double rot) {
  if (r <= 0) return;
  final path = Path();
  for (var i = 0; i < 8; i++) {
    final a = rot + i * pi / 4;
    final rr = i.isEven ? r : r * 0.22;
    final p = c + Offset(cos(a), sin(a)) * rr;
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  canvas.drawPath(path..close(), Paint()..color = color);
}

/// Chain reaction: little explosions pop one after another, running out from
/// the centre along the cleared line (or scattered round a big blast). Hotter
/// streaks add more pops.
void _paintChain(Canvas canvas, double cell, Burst b, double t) {
  final rnd = Random(b.seed + 11);
  final ice = b.kind == BurstKind.ice;
  final colors = ice ? _iceColors : _fireColors;
  final along = b.spread != Offset.zero;
  final n = along ? 6 + min(b.streak, 4) : (3 + b.power).round() + min(b.streak, 4);
  for (var i = 0; i < n; i++) {
    Offset pos;
    double delay;
    if (along) {
      // Alternate sides, moving out from the middle of the line.
      final step = (i ~/ 2 + 1) / (n ~/ 2 + 1);
      final side = i.isEven ? 1.0 : -1.0;
      pos = b.center + b.spread * step * side + Offset(rnd.nextDouble() - 0.5, rnd.nextDouble() - 0.5) * 0.5;
      delay = 0.06 + step * 0.28;
    } else {
      final a = rnd.nextDouble() * 2 * pi;
      pos = b.center + Offset(cos(a), sin(a)) * (0.8 + rnd.nextDouble() * 0.4 * b.power);
      delay = 0.08 + rnd.nextDouble() * 0.35;
    }
    final lt = (t - delay) / 0.32;
    if (lt < 0 || lt > 1) continue;
    final p = pos * cell;
    final k = _popScale(lt, grow: 0.3);
    final r = cell * (0.38 + rnd.nextDouble() * 0.22);
    if (ice) {
      _twinkle(canvas, p, r * 1.5 * k, colors[0].withValues(alpha: 1 - lt), lt * 2 + i);
      canvas.drawCircle(p, r * 0.5 * k, Paint()..color = colors[2].withValues(alpha: 0.8 * (1 - lt)));
    } else {
      canvas.drawCircle(p, r * k, Paint()..color = colors[2].withValues(alpha: 0.85 * (1 - lt)));
      canvas.drawCircle(p, r * 0.6 * k, Paint()..color = colors[1].withValues(alpha: 0.95 * (1 - lt)));
      canvas.drawCircle(p, r * 0.3 * k, Paint()..color = colors[0].withValues(alpha: 1 - lt));
    }
    canvas.drawCircle(
      p,
      r * (0.6 + 1.2 * lt),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1, cell * 0.06 * (1 - lt))
        ..color = colors[1].withValues(alpha: 0.8 * (1 - lt)),
    );
  }
}

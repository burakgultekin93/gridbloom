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
  Burst(this.center, this.kind, this.power, this.start, this.seed);

  Duration get duration => Duration(milliseconds: (650 + 220 * min(power, 4)).round());
}

const _iceColors = [Color(0xFFFFFFFF), Color(0xFFCFF1FF), Color(0xFF8FD8FF), Color(0xFF4FB2F0)];
const _fireColors = [Color(0xFFFFF1A8), Color(0xFFFFC23D), Color(0xFFFF7A1A), Color(0xFFE0301E)];

void paintBursts(Canvas canvas, double cell, List<Burst> bursts, DateTime now) {
  for (final b in bursts) {
    final t = now.difference(b.start).inMicroseconds / b.duration.inMicroseconds;
    if (t < 0 || t > 1) continue;
    if (b.kind == BurstKind.ice) {
      _paintIce(canvas, cell, b, t);
    } else {
      _paintFire(canvas, cell, b, t);
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

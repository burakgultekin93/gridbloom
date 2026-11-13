import 'dart:math';

import 'package:flutter/material.dart';

/// Drawing for heat mode: frozen cells, burning blocks, and the short
/// effects when ice cracks or melts, fire jumps, and fire meets ice.

/// Ice cell melted away: shards fly out and fall.
class IceShatter {
  final int r, c;
  final DateTime start;
  IceShatter(this.r, this.c, this.start);
  static const duration = Duration(milliseconds: 820);
}

/// Ice cell cracked but held: a white crack flashes across it.
class IceCrack {
  final int r, c;
  final DateTime start;
  IceCrack(this.r, this.c, this.start);
  static const duration = Duration(milliseconds: 600);
}

/// Fire jumping from one cell to a neighbour: a fireball on a small arc.
class FireJump {
  final int fr, fc, tr, tc;
  final DateTime start;
  FireJump(this.fr, this.fc, this.tr, this.tc, this.start);
  static const duration = Duration(milliseconds: 420);
}

/// Fire ran into ice: a white cloud of steam rises.
class SteamPuff {
  final int r, c;
  final DateTime start;
  SteamPuff(this.r, this.c, this.start);
  static const duration = Duration(milliseconds: 1100);
}

/// A new hazard landing on a cell: a ring closing in on it.
class HazardArrival {
  final int r, c;
  final bool fire;
  final DateTime start;
  HazardArrival(this.r, this.c, this.fire, this.start);
  static const duration = Duration(milliseconds: 520);
}

double _t(DateTime now, DateTime start, Duration d) => now.difference(start).inMicroseconds / d.inMicroseconds;

/// A frozen cell: a thick, frosted slab with a snowflake inside. Two
/// layers look deeper blue with a double rim and two pips.
void paintFrozenCell(Canvas canvas, Rect rect, int layers, double seconds, {double opacity = 1}) {
  final w = rect.width;
  final cell = rect.deflate(w * 0.05);
  final thick = layers >= 2;
  final r = RRect.fromRectAndRadius(cell, Radius.circular(w * 0.12));
  final a = opacity;
  canvas.drawRRect(
    r,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: thick
            ? [
                const Color(0xFFBFE9FF).withValues(alpha: a),
                const Color(0xFF4F9FE0).withValues(alpha: a),
                const Color(0xFF1C4A8A).withValues(alpha: a),
              ]
            : [
                const Color(0xFFF2FBFF).withValues(alpha: a),
                const Color(0xFFA8DFFF).withValues(alpha: 0.95 * a),
                const Color(0xFF5AAEE6).withValues(alpha: 0.95 * a),
              ],
      ).createShader(cell),
  );
  canvas.save();
  canvas.clipRRect(r);
  // Frost along the top edge and a slow shimmer sweeping across.
  canvas.drawRect(
    Rect.fromLTWH(cell.left, cell.top, cell.width, cell.height * 0.2),
    Paint()..color = Colors.white.withValues(alpha: 0.4 * a),
  );
  final sweep = (seconds * 0.35 + (rect.left + rect.top) / (w * 11)) % 1.6 - 0.3;
  final band = Rect.fromLTWH(cell.left + cell.width * (sweep - 0.2), cell.top, cell.width * 0.4, cell.height);
  canvas.drawRect(
    band,
    Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.35 * a),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(band),
  );
  canvas.restore();

  // Snowflake.
  final c = cell.center;
  final arm = cell.width * 0.3;
  final ink = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = max(1.0, w * 0.055)
    ..color = (thick ? const Color(0xFFEAF8FF) : const Color(0xFF2F7FC4)).withValues(alpha: 0.9 * a);
  for (var k = 0; k < 6; k++) {
    final ang = k * pi / 3 + pi / 6;
    final d = Offset(cos(ang), sin(ang));
    final tip = c + d * arm;
    canvas.drawLine(c, tip, ink);
    final mid = c + d * arm * 0.6;
    final n = Offset(-d.dy, d.dx) * arm * 0.22;
    canvas.drawLine(mid, mid + d * arm * 0.2 + n, ink);
    canvas.drawLine(mid, mid + d * arm * 0.2 - n, ink);
  }

  // Rim: double for thick ice, plus two pips in the corner.
  final rim = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(1.0, w * 0.05)
    ..color = Colors.white.withValues(alpha: 0.85 * a);
  canvas.drawRRect(r.deflate(0.5), rim);
  if (thick) {
    canvas.drawRRect(r.deflate(w * 0.1), rim..strokeWidth = max(0.8, w * 0.03));
    for (var k = 0; k < 2; k++) {
      canvas.drawCircle(
        Offset(cell.right - w * (0.14 + 0.13 * k), cell.top + w * 0.14),
        w * 0.045,
        Paint()..color = Colors.white.withValues(alpha: 0.95 * a),
      );
    }
  }
}

/// Flames licking up a burning block, with the moves left on its fuse.
/// The glow pulses faster as the fuse runs down.
void paintBurning(Canvas canvas, Rect rect, int fuse, double seconds, int seed) {
  final w = rect.width;
  final urgent = fuse <= 1;
  final speed = urgent ? 9.0 : (fuse == 2 ? 6.0 : 4.0);
  final pulse = 0.5 + 0.5 * sin(seconds * speed + seed);

  // Hot glow around the block.
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect.deflate(w * 0.02), Radius.circular(w * 0.2)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * (0.08 + 0.05 * pulse)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.12)
      ..color = (urgent ? const Color(0xFFFF3A1A) : const Color(0xFFFF8A2A)).withValues(alpha: 0.55 + 0.35 * pulse),
  );

  // Three flame tongues rising from the bottom, each flickering on its own.
  canvas.save();
  canvas.clipRect(rect.inflate(w * 0.3));
  for (var k = 0; k < 3; k++) {
    final x = rect.left + w * (0.25 + 0.25 * k);
    final flick = sin(seconds * (7 + k * 1.7) + seed * 1.3 + k * 2.1);
    final h = w * (0.55 + 0.12 * flick + (k == 1 ? 0.15 : 0));
    final base = rect.bottom - w * 0.1;
    final sway = w * 0.06 * sin(seconds * 5 + k + seed);
    Path tongue(double width, double height) => Path()
      ..moveTo(x - width, base)
      ..quadraticBezierTo(x - width * 1.1, base - height * 0.55, x + sway, base - height)
      ..quadraticBezierTo(x + width * 1.1, base - height * 0.55, x + width, base)
      ..close();
    canvas.drawPath(tongue(w * 0.13, h), Paint()..color = const Color(0xFFE0301E).withValues(alpha: 0.85));
    canvas.drawPath(tongue(w * 0.09, h * 0.75), Paint()..color = const Color(0xFFFF8A1A).withValues(alpha: 0.9));
    canvas.drawPath(tongue(w * 0.05, h * 0.45), Paint()..color = const Color(0xFFFFE08A).withValues(alpha: 0.95));
  }
  canvas.restore();

  // Fuse counter in a dark badge at the top right.
  final badge = Offset(rect.right - w * 0.2, rect.top + w * 0.2);
  final br = w * (0.17 + (urgent ? 0.03 * pulse : 0));
  canvas.drawCircle(badge, br, Paint()..color = const Color(0xFF1A0804).withValues(alpha: 0.85));
  canvas.drawCircle(
    badge,
    br,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, w * 0.035)
      ..color = urgent ? const Color(0xFFFF5A3A) : const Color(0xFFFFB347),
  );
  final tp = TextPainter(
    text: TextSpan(
      text: '$fuse',
      style: TextStyle(
        color: urgent ? const Color(0xFFFFD0C0) : const Color(0xFFFFE6B0),
        fontSize: w * 0.22,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, badge - Offset(tp.width / 2, tp.height / 2));
}

/// Every running heat-mode effect, drawn above the blocks.
void paintHeatFx(
  Canvas canvas,
  double cell,
  DateTime now, {
  required List<IceShatter> shards,
  required List<IceCrack> cracks,
  required List<FireJump> jumps,
  required List<SteamPuff> steam,
  required List<HazardArrival> arrivals,
}) {
  Rect at(int r, int c) => Rect.fromLTWH(c * cell, r * cell, cell, cell);

  for (final s in shards) {
    final t = _t(now, s.start, IceShatter.duration);
    if (t < 0 || t > 1) continue;
    final rect = at(s.r, s.c);
    final rnd = Random(s.r * 31 + s.c * 7);
    final ease = Curves.easeOutCubic.transform(t);
    // A bright frost flash first.
    if (t < 0.25) {
      canvas.drawCircle(
        rect.center,
        cell * (0.5 + t),
        Paint()
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.3)
          ..color = Colors.white.withValues(alpha: 0.9 * (1 - t / 0.25)),
      );
    }
    for (var k = 0; k < 7; k++) {
      final ang = k * 2 * pi / 7 + rnd.nextDouble() * 0.6;
      final dist = cell * (0.5 + rnd.nextDouble() * 0.9) * ease;
      final p = rect.center + Offset(cos(ang), sin(ang)) * dist + Offset(0, cell * 1.2 * t * t);
      final size = cell * (0.12 + rnd.nextDouble() * 0.12) * (1 - 0.5 * t);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(ang + t * 6 * (k.isEven ? 1 : -1));
      final shard = Path()
        ..moveTo(0, -size * 1.4)
        ..lineTo(size * 0.7, 0)
        ..lineTo(0, size * 1.1)
        ..lineTo(-size * 0.6, 0)
        ..close();
      canvas.drawPath(shard, Paint()..color = const Color(0xFFCFF1FF).withValues(alpha: 1 - t));
      canvas.drawPath(
        shard,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(0.8, cell * 0.025)
          ..color = Colors.white.withValues(alpha: 1 - t),
      );
      canvas.restore();
    }
  }

  for (final k in cracks) {
    final t = _t(now, k.start, IceCrack.duration);
    if (t < 0 || t > 1) continue;
    final rect = at(k.r, k.c);
    final rnd = Random(k.r * 13 + k.c * 17 + 5);
    final grow = Curves.easeOut.transform(min(1.0, t * 3));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = max(1.0, cell * 0.05)
      ..color = Colors.white.withValues(alpha: 1 - t);
    for (var n = 0; n < 4; n++) {
      final ang = n * pi / 2 + rnd.nextDouble() * 0.8;
      var p = rect.center;
      final path = Path()..moveTo(p.dx, p.dy);
      for (var s = 0; s < 3; s++) {
        p += Offset(cos(ang + (rnd.nextDouble() - 0.5)), sin(ang + (rnd.nextDouble() - 0.5))) * cell * 0.16 * grow;
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  for (final j in jumps) {
    final t = _t(now, j.start, FireJump.duration);
    if (t < 0 || t > 1) continue;
    final from = at(j.fr, j.fc).center, to = at(j.tr, j.tc).center;
    final e = Curves.easeInOut.transform(t);
    final p = Offset.lerp(from, to, e)! - Offset(0, cell * 0.6 * sin(pi * t));
    for (var k = 4; k >= 0; k--) {
      // A short trail behind the fireball.
      final tt = max(0.0, e - k * 0.06);
      final q = Offset.lerp(from, to, tt)! - Offset(0, cell * 0.6 * sin(pi * max(0.0, t - k * 0.06)));
      canvas.drawCircle(
        q,
        cell * (0.22 - k * 0.03),
        Paint()
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.08)
          ..color = Color.lerp(
            const Color(0xFFFFE08A),
            const Color(0xFFE0301E),
            k / 4,
          )!.withValues(alpha: 0.9 - k * 0.15),
      );
    }
    canvas.drawCircle(p, cell * 0.12, Paint()..color = Colors.white.withValues(alpha: 0.9));
  }

  for (final s in steam) {
    final t = _t(now, s.start, SteamPuff.duration);
    if (t < 0 || t > 1) continue;
    final rect = at(s.r, s.c);
    final rnd = Random(s.r * 41 + s.c * 3);
    for (var k = 0; k < 6; k++) {
      final dx = (rnd.nextDouble() - 0.5) * cell * 0.9;
      final rise = cell * (0.3 + rnd.nextDouble() * 0.9) * Curves.easeOut.transform(t);
      final rad = cell * (0.18 + 0.35 * t) * (0.7 + rnd.nextDouble() * 0.5);
      canvas.drawCircle(
        rect.center + Offset(dx + sin(t * 6 + k) * cell * 0.08, -rise),
        rad,
        Paint()
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, rad * 0.5)
          ..color = const Color(0xFFF4F8FF).withValues(alpha: 0.55 * (1 - t)),
      );
    }
  }

  for (final h in arrivals) {
    final t = _t(now, h.start, HazardArrival.duration);
    if (t < 0 || t > 1) continue;
    final rect = at(h.r, h.c);
    final color = h.fire ? const Color(0xFFFF7A1A) : const Color(0xFFBFEAFF);
    final rad = cell * (1.6 - 1.1 * Curves.easeIn.transform(t));
    canvas.drawCircle(
      rect.center,
      rad,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.1
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.06)
        ..color = color.withValues(alpha: 0.9 * (0.3 + 0.7 * t)),
    );
  }
}

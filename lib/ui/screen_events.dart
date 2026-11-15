import 'dart:math';

import 'package:flutter/material.dart';

/// Full-screen moments for the biggest moves: the screen erupts like a
/// volcano when the streak is hot, or freezes over like a glacier and then
/// melts away when it is cold.
enum ScreenEventKind { volcano, glacier }

class ScreenEvent {
  final ScreenEventKind kind;
  final DateTime start;

  /// 0.6 for a 3+ line clear, 1 for a board clear or a new record.
  final double power;
  final int seed;

  ScreenEvent(this.kind, this.start, this.power, this.seed);

  Duration get duration => kind == ScreenEventKind.volcano
      ? Duration(milliseconds: (1300 + 600 * power).round())
      : Duration(milliseconds: (1500 + 700 * power).round());

  double progress(DateTime now) => now.difference(start).inMicroseconds / duration.inMicroseconds;
}

class ScreenEventPainter extends CustomPainter {
  final List<ScreenEvent> events;
  final DateTime now;

  ScreenEventPainter(this.events, this.now);

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in events) {
      final t = e.progress(now);
      if (t < 0 || t > 1) continue;
      if (e.kind == ScreenEventKind.volcano) {
        _volcano(canvas, size, e, t);
      } else {
        _glacier(canvas, size, e, t);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

const _lava = [Color(0xFFFFF4C2), Color(0xFFFFD23D), Color(0xFFFF8A1A), Color(0xFFE8361C), Color(0xFF8A1206)];
const _frost = [Color(0xFFFFFFFF), Color(0xFFDDF6FF), Color(0xFF9EE3FF), Color(0xFF52BDF5)];

double _bell(double t, double a, double b) {
  if (t <= a || t >= b) return 0;
  return sin((t - a) / (b - a) * pi);
}

// ---------------------------------------------------------------------------
// Volcano: the floor of the screen glows, lava surges up from the bottom, a
// fountain of lava bombs bursts into the air and rains back down.

void _volcano(Canvas canvas, Size size, ScreenEvent e, double t) {
  final w = size.width, h = size.height;
  final rnd = Random(e.seed);
  final add = BlendMode.plus;

  // Opening flash over the whole screen.
  if (t < 0.18) {
    final k = 1 - t / 0.18;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = add
        ..color = const Color(0xFFFF7A1A).withValues(alpha: 0.42 * k * k * e.power),
    );
  }

  // Red-hot glow rising from the bottom.
  final glow = _bell(t, 0, 1) * e.power;
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..blendMode = add
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFFFF5A12).withValues(alpha: 0.75 * glow),
          const Color(0xFFFF2A08).withValues(alpha: 0.25 * glow),
          const Color(0x00FF2A08),
        ],
        stops: const [0, 0.35, 0.75],
      ).createShader(Offset.zero & size),
  );

  // Lava surface: surges up from the bottom, wobbles, then drains away.
  final surge = _bell(t, 0.02, 0.95);
  final level = h * (0.06 + 0.16 * e.power) * surge;
  if (level > 1) {
    Path surface(double lift, double amp, double phase) {
      final p = Path()..moveTo(0, h);
      const steps = 24;
      for (var i = 0; i <= steps; i++) {
        final x = w * i / steps;
        final y = h - level - lift + sin(i * 0.9 + t * 14 + phase) * amp + sin(i * 2.3 - t * 9) * amp * 0.4;
        p.lineTo(x, y);
      }
      return p
        ..lineTo(w, h)
        ..close();
    }

    final body = Rect.fromLTWH(0, h - level - 30, w, level + 30);
    canvas.drawPath(
      surface(10, 12, 1.3),
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
        ..color = const Color(0xFFFF8A1A).withValues(alpha: 0.7),
    );
    canvas.drawPath(
      surface(0, 9, 0),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_lava[1], _lava[2], _lava[3], _lava[4]],
          stops: const [0, 0.2, 0.55, 1],
        ).createShader(body),
    );
    // Bright crust line and bubbles on the surface.
    canvas.drawPath(
      surface(0, 9, 0),
      Paint()
        ..blendMode = add
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
        ..color = _lava[0].withValues(alpha: 0.9),
    );
    final brnd = Random(e.seed + 5);
    for (var i = 0; i < 14; i++) {
      final x = brnd.nextDouble() * w;
      final bt = (t * 3 + brnd.nextDouble()) % 1;
      final y = h - level * (0.2 + 0.7 * brnd.nextDouble());
      canvas.drawCircle(
        Offset(x, y),
        3 + 9 * bt,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _lava[0].withValues(alpha: 0.8 * (1 - bt)),
      );
    }
  }

  // Lava fountain: bombs shot up from vents along the bottom.
  final vents = [w * 0.5, w * 0.2, w * 0.8];
  final bombs = (34 + 30 * e.power).round();
  const g = 2.6; // gravity in screen heights per unit of t squared
  for (var i = 0; i < bombs; i++) {
    final vent = vents[i % vents.length] + (rnd.nextDouble() - 0.5) * w * 0.08;
    final launch = 0.04 + rnd.nextDouble() * 0.35 + (i % vents.length) * 0.06;
    final life = 0.45 + rnd.nextDouble() * 0.4;
    final lt = (t - launch) / life;
    if (lt <= 0 || lt >= 1) continue;
    final vy = h * (1.5 + rnd.nextDouble() * 1.4) * (0.7 + 0.3 * e.power);
    final vx = (rnd.nextDouble() - 0.5) * w * 0.9;
    final tt = lt * life;
    Offset at(double s) => Offset(vent + vx * s, h - level * 0.6 - vy * s + h * g * s * s);
    final p = at(tt);
    final tail = at(max(0, tt - 0.05));
    final r = (4 + rnd.nextDouble() * 10) * (1 - 0.4 * lt);
    final color = _lava[min(4, (lt * 3.2 + rnd.nextDouble() * 0.8).floor())];
    // Smoke trail.
    canvas.drawLine(
      tail,
      p,
      Paint()
        ..strokeWidth = r * 1.4
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.8)
        ..color = color.withValues(alpha: 0.55 * (1 - lt)),
    );
    canvas.drawCircle(
      p,
      r * 2.2,
      Paint()
        ..blendMode = add
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r)
        ..color = color.withValues(alpha: 0.6 * (1 - lt)),
    );
    canvas.drawCircle(p, r, Paint()..color = color);
    canvas.drawCircle(p - Offset(r * 0.3, r * 0.3), r * 0.4, Paint()..color = _lava[0].withValues(alpha: 1 - lt));
  }

  // Fiery sparks swirling up the whole screen.
  final sparks = (40 * e.power).round();
  for (var i = 0; i < sparks; i++) {
    final st = (t * (1.2 + rnd.nextDouble()) + rnd.nextDouble()) % 1;
    final x = rnd.nextDouble() * w + sin(st * 8 + i) * 20;
    final y = h * (1 - st * 1.1);
    final a = _bell(t, 0, 1) * (1 - st);
    canvas.drawCircle(
      Offset(x, y),
      1.5 + rnd.nextDouble() * 2.5,
      Paint()
        ..blendMode = add
        ..color = _lava[rnd.nextInt(3)].withValues(alpha: a),
    );
  }
}

// ---------------------------------------------------------------------------
// Glacier: frost grows in from every edge with ice ferns, the whole screen
// cracks with a bright flash, then the ice melts and runs down in drips.

void _glacier(Canvas canvas, Size size, ScreenEvent e, double t) {
  final w = size.width, h = size.height;
  final add = BlendMode.plus;
  final grow = Curves.easeOutCubic.transform((t / 0.35).clamp(0.0, 1.0));
  final melt = ((t - 0.5) / 0.5).clamp(0.0, 1.0);
  final hold = 1 - Curves.easeInQuad.transform(melt);
  final depth = (0.18 + 0.14 * e.power) * grow;

  // Cold flash.
  if (t < 0.15) {
    final k = 1 - t / 0.15;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = add
        ..color = const Color(0xFF7FDBFF).withValues(alpha: 0.4 * k * k * e.power),
    );
  }

  // Frost creeping in from the edges (and sliding down as it melts).
  final slide = h * 0.25 * Curves.easeInQuad.transform(melt);
  final edges = [
    (Alignment.topCenter, Alignment.bottomCenter),
    (Alignment.bottomCenter, Alignment.topCenter),
    (Alignment.centerLeft, Alignment.centerRight),
    (Alignment.centerRight, Alignment.centerLeft),
  ];
  for (final (from, to) in edges) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: from,
          end: to,
          colors: [
            _frost[1].withValues(alpha: 0.85 * hold),
            _frost[2].withValues(alpha: 0.35 * hold),
            _frost[2].withValues(alpha: 0),
          ],
          stops: [0, depth * 0.55, depth],
        ).createShader(Offset.zero & size),
    );
  }

  // Ice ferns: branching crystal lines growing in from the edges.
  canvas.save();
  canvas.translate(0, slide);
  final rnd = Random(e.seed);
  final fern = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 2
    ..color = Colors.white.withValues(alpha: 0.85 * hold);
  final n = (14 + 10 * e.power).round();
  for (var i = 0; i < n; i++) {
    final side = i % 4;
    final u = rnd.nextDouble();
    late Offset start;
    late double dir;
    switch (side) {
      case 0:
        start = Offset(u * w, 0);
        dir = pi / 2;
      case 1:
        start = Offset(u * w, h);
        dir = -pi / 2;
      case 2:
        start = Offset(0, u * h);
        dir = 0;
      default:
        start = Offset(w, u * h);
        dir = pi;
    }
    final len = min(w, h) * (0.12 + rnd.nextDouble() * 0.2) * (0.6 + 0.4 * e.power) * grow;
    _fernBranch(canvas, start, dir + (rnd.nextDouble() - 0.5) * 0.6, len, 3, rnd, fern);
  }
  canvas.restore();

  // The big crack: bright fracture lines across the screen with a flash.
  if (t > 0.3 && t < 0.62) {
    final ct = (t - 0.3) / 0.32;
    final k = 1 - ct;
    if (ct < 0.25) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..blendMode = add
          ..color = Colors.white.withValues(alpha: 0.35 * (1 - ct / 0.25) * e.power),
      );
    }
    final crnd = Random(e.seed + 9);
    final centre = Offset(w * (0.35 + 0.3 * crnd.nextDouble()), h * (0.35 + 0.3 * crnd.nextDouble()));
    final reach = Curves.easeOutExpo.transform(min(1.0, ct * 3)) * max(w, h);
    for (var i = 0; i < 9; i++) {
      var a = i * 2 * pi / 9 + crnd.nextDouble() * 0.5;
      var p = centre;
      final path = Path()..moveTo(p.dx, p.dy);
      for (var s = 0; s < 8; s++) {
        a += (crnd.nextDouble() - 0.5) * 0.7;
        p += Offset(cos(a), sin(a)) * reach / 8;
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..blendMode = add
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
          ..color = _frost[2].withValues(alpha: 0.8 * k),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white.withValues(alpha: k),
      );
    }
  }

  // Melting: drips run down from the top and water sheets glint.
  if (melt > 0) {
    final drnd = Random(e.seed + 17);
    final drips = (16 + 12 * e.power).round();
    for (var i = 0; i < drips; i++) {
      final x = drnd.nextDouble() * w;
      final delay = drnd.nextDouble() * 0.4;
      final mt = ((melt - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (mt <= 0) continue;
      final speed = 0.6 + drnd.nextDouble() * 0.8;
      final y = h * (0.02 + Curves.easeInQuad.transform(mt) * speed);
      final len = h * (0.05 + 0.1 * drnd.nextDouble()) * mt;
      final a = 1 - mt * 0.7;
      canvas.drawLine(
        Offset(x, y - len),
        Offset(x, y),
        Paint()
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _frost[2].withValues(alpha: 0),
              _frost[1].withValues(alpha: 0.9 * a),
            ],
          ).createShader(Rect.fromPoints(Offset(x, y - len), Offset(x + 1, y))),
      );
      canvas.drawCircle(
        Offset(x, y),
        4.5,
        Paint()
          ..blendMode = add
          ..color = _frost[0].withValues(alpha: a),
      );
    }
  }

  // Glittering ice dust over the whole screen.
  final grnd = Random(e.seed + 31);
  final dust = (50 * e.power).round();
  for (var i = 0; i < dust; i++) {
    final x = grnd.nextDouble() * w;
    final y = grnd.nextDouble() * h + h * 0.2 * melt;
    final tw = 0.5 + 0.5 * sin(t * 25 + i * 1.7);
    final a = _bell(t, 0.05, 1) * tw;
    final r = 2 + grnd.nextDouble() * 4;
    final p = Paint()
      ..blendMode = add
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: a);
    canvas.drawLine(Offset(x - r, y), Offset(x + r, y), p);
    canvas.drawLine(Offset(x, y - r), Offset(x, y + r), p);
  }
}

void _fernBranch(Canvas canvas, Offset p, double dir, double len, int depth, Random rnd, Paint paint) {
  if (depth == 0 || len < 4) return;
  final end = p + Offset(cos(dir), sin(dir)) * len;
  canvas.drawLine(p, end, paint);
  final n = 3;
  for (var i = 1; i <= n; i++) {
    final q = Offset.lerp(p, end, i / (n + 1))!;
    final sub = len * 0.45 * (1 - i / (n + 2));
    _fernBranch(canvas, q, dir + 0.9 + (rnd.nextDouble() - 0.5) * 0.3, sub, depth - 1, rnd, paint);
    _fernBranch(canvas, q, dir - 0.9 + (rnd.nextDouble() - 0.5) * 0.3, sub, depth - 1, rnd, paint);
  }
}

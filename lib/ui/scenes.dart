import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Ready-made board pictures, drawn in code so they stay sharp at any size.
const sceneNames = <String>[
  'Gün batımı',
  'Dağlar',
  'Yıldızlı gece',
  'Çiçek tarlası',
  'Okyanus',
  'Kuzey ışıkları',
  'Sakura',
  'Çöl',
  'Gökkuşağı',
  'Sonbahar ormanı',
  'Şehir gecesi',
  'Mercan resifi',
];

int get sceneCount => sceneNames.length;

/// Renders scene [index] to an image for the board.
Future<ui.Image> renderScene(int index, {int size = 768}) {
  final rec = ui.PictureRecorder();
  paintScene(Canvas(rec), Size.square(size.toDouble()), index);
  return rec.endRecording().toImage(size, size);
}

double _rand(int i, int salt) {
  final x = sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

void _sky(Canvas c, Size s, List<Color> colors, {List<double>? stops, double to = 1}) {
  final r = Rect.fromLTWH(0, 0, s.width, s.height * to);
  c.drawRect(
    r,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
        stops: stops,
      ).createShader(r),
  );
}

Path _ridge(Size s, double baseY, double amp, int seed, {int points = 9}) {
  final p = Path()..moveTo(0, s.height);
  for (var i = 0; i <= points; i++) {
    final x = s.width * i / points;
    final y = baseY - amp * (0.3 + 0.7 * _rand(i, seed));
    p.lineTo(x, y);
  }
  return p
    ..lineTo(s.width, s.height)
    ..close();
}

Path _hill(Size s, double y, double amp, double phase, double freq) {
  final p = Path()..moveTo(0, s.height);
  for (var x = 0.0; x <= s.width; x += s.width / 60) {
    p.lineTo(x, y + sin(x / s.width * pi * freq + phase) * amp);
  }
  return p
    ..lineTo(s.width, s.height)
    ..close();
}

void _cloud(Canvas c, Offset o, double r, Color col) {
  final p = Paint()..color = col;
  c.drawCircle(o, r, p);
  c.drawCircle(o + Offset(r * 0.9, r * 0.2), r * 0.8, p);
  c.drawCircle(o + Offset(-r * 0.9, r * 0.25), r * 0.7, p);
  c.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(o.dx - r * 1.5, o.dy, r * 3.1, r * 0.8), Radius.circular(r * 0.4)),
    p,
  );
}

void paintScene(Canvas c, Size s, int index) {
  final w = s.width, h = s.height;
  c.save();
  c.clipRect(Offset.zero & s);
  switch (index % 12) {
    case 0: // Sunset over the sea
      _sky(
        c,
        s,
        const [Color(0xFF3B1E54), Color(0xFFD9466F), Color(0xFFFF9A4A), Color(0xFFFFD27A)],
        stops: const [0, 0.4, 0.75, 1],
        to: 0.62,
      );
      c.drawCircle(Offset(w * 0.5, h * 0.6), w * 0.17, Paint()..color = const Color(0xFFFFE39A));
      final sea = Rect.fromLTWH(0, h * 0.62, w, h * 0.38);
      c.drawRect(
        sea,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8A3A6B), Color(0xFF2A1640)],
          ).createShader(sea),
      );
      for (var i = 0; i < 9; i++) {
        final y = h * (0.65 + i * 0.035);
        final half = w * (0.16 - i * 0.012);
        c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(w * 0.5 - half, y, w * 0.5 + half, y + h * 0.012), Radius.circular(h)),
          Paint()..color = const Color(0xFFFFD27A).withValues(alpha: 0.8 - i * 0.07),
        );
      }
    case 1: // Mountains
      _sky(c, s, const [Color(0xFF7EC8F0), Color(0xFFDDF1FA)]);
      c.drawCircle(Offset(w * 0.78, h * 0.18), w * 0.07, Paint()..color = const Color(0xFFFFF3C4));
      c.drawPath(_ridge(s, h * 0.45, h * 0.25, 3, points: 6), Paint()..color = const Color(0xFF8DA7C4));
      // Snow caps on the far ridge.
      for (var i = 1; i < 6; i++) {
        final x = w * i / 6, y = h * 0.45 - h * 0.25 * (0.3 + 0.7 * _rand(i, 3));
        c.drawPath(
          Path()
            ..moveTo(x, y)
            ..lineTo(x - w * 0.05, y + h * 0.06)
            ..lineTo(x + w * 0.05, y + h * 0.06)
            ..close(),
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
      }
      c.drawPath(_ridge(s, h * 0.65, h * 0.2, 7, points: 8), Paint()..color = const Color(0xFF4F7A8C));
      c.drawPath(_hill(s, h * 0.82, h * 0.04, 1, 3), Paint()..color = const Color(0xFF3F7D4E));
      c.drawPath(_hill(s, h * 0.9, h * 0.03, 2, 4), Paint()..color = const Color(0xFF2F5F3B));
    case 2: // Starry night
      _sky(c, s, const [Color(0xFF0B1033), Color(0xFF26306B), Color(0xFF4A3F7A)]);
      for (var i = 0; i < 140; i++) {
        final r = 0.6 + _rand(i, 4) * 2.2;
        c.drawCircle(
          Offset(_rand(i, 1) * w, _rand(i, 2) * h * 0.75),
          r * w / 400,
          Paint()..color = Colors.white.withValues(alpha: 0.4 + 0.6 * _rand(i, 3)),
        );
      }
      c.drawCircle(Offset(w * 0.72, h * 0.22), w * 0.1, Paint()..color = const Color(0xFFFFF4C8));
      c.drawCircle(Offset(w * 0.76, h * 0.2), w * 0.09, Paint()..color = const Color(0xFF151A45));
      c.drawPath(_hill(s, h * 0.85, h * 0.05, 0.5, 2.2), Paint()..color = const Color(0xFF101530));
    case 3: // Flower field
      _sky(c, s, const [Color(0xFF8ED1F5), Color(0xFFE6F6FC)], to: 0.5);
      _cloud(c, Offset(w * 0.25, h * 0.18), w * 0.07, Colors.white);
      _cloud(c, Offset(w * 0.7, h * 0.12), w * 0.05, Colors.white);
      c.drawPath(_hill(s, h * 0.48, h * 0.03, 0, 2), Paint()..color = const Color(0xFF7CC46A));
      c.drawPath(_hill(s, h * 0.6, h * 0.03, 1.5, 3), Paint()..color = const Color(0xFF5CAE4E));
      const petals = [Color(0xFFFF6B8B), Color(0xFFFFD34D), Color(0xFFFFFFFF), Color(0xFFB58CFF), Color(0xFFFF9248)];
      for (var i = 0; i < 160; i++) {
        final y = h * (0.52 + 0.48 * _rand(i, 5));
        final x = _rand(i, 6) * w;
        final r = w * (0.006 + 0.014 * (y - h * 0.5) / (h * 0.5));
        c.drawCircle(Offset(x, y), r, Paint()..color = petals[i % petals.length]);
        c.drawCircle(Offset(x, y), r * 0.4, Paint()..color = const Color(0xFFFFE08A));
      }
    case 4: // Ocean
      _sky(c, s, const [Color(0xFF5FB8F2), Color(0xFFC9ECFA)], to: 0.45);
      c.drawCircle(Offset(w * 0.25, h * 0.2), w * 0.08, Paint()..color = const Color(0xFFFFF0A8));
      _cloud(c, Offset(w * 0.7, h * 0.2), w * 0.06, Colors.white.withValues(alpha: 0.9));
      const blues = [Color(0xFF2E9BD6), Color(0xFF1F7FC0), Color(0xFF1767A8), Color(0xFF0F4E8A), Color(0xFF0B3B6E)];
      for (var i = 0; i < blues.length; i++) {
        c.drawPath(_hill(s, h * (0.45 + i * 0.11), h * 0.025, i * 1.3, 6.0 + i), Paint()..color = blues[i]);
        final foam = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.006
          ..color = Colors.white.withValues(alpha: 0.5);
        final p = Path()..moveTo(0, h * (0.45 + i * 0.11));
        for (var x = 0.0; x <= w; x += w / 60) {
          p.lineTo(x, h * (0.45 + i * 0.11) + sin(x / w * pi * (6 + i) + i * 1.3) * h * 0.025);
        }
        c.drawPath(p, foam);
      }
    case 5: // Northern lights
      _sky(c, s, const [Color(0xFF041427), Color(0xFF0B2A44), Color(0xFF123B52)]);
      for (var i = 0; i < 80; i++) {
        c.drawCircle(
          Offset(_rand(i, 7) * w, _rand(i, 8) * h * 0.6),
          w * 0.003,
          Paint()..color = Colors.white.withValues(alpha: 0.6),
        );
      }
      for (final (y, col, ph) in const [
        (0.3, Color(0xFF3CF2A0), 0.0),
        (0.38, Color(0xFF7A5CFF), 1.4),
        (0.24, Color(0xFF2BD9D9), 2.6),
      ]) {
        final p = Path();
        for (var x = 0.0; x <= w; x += w / 50) {
          final yy = h * y + sin(x / w * pi * 2 + ph) * h * 0.08;
          x == 0 ? p.moveTo(x, yy) : p.lineTo(x, yy);
        }
        c.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = h * 0.09
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.04)
            ..color = col.withValues(alpha: 0.55),
        );
      }
      c.drawPath(_ridge(s, h * 0.78, h * 0.08, 11, points: 10), Paint()..color = const Color(0xFF0A1C2C));
      c.drawPath(_hill(s, h * 0.9, h * 0.02, 0, 2), Paint()..color = const Color(0xFFDCEBF5));
    case 6: // Cherry blossom
      _sky(c, s, const [Color(0xFFFFE3EC), Color(0xFFFFF6F0)]);
      c.drawCircle(Offset(w * 0.7, h * 0.3), w * 0.15, Paint()..color = const Color(0xFFFF8FA8).withValues(alpha: 0.5));
      final branch = Paint()
        ..color = const Color(0xFF5A3A3A)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      c.drawPath(
        Path()
          ..moveTo(0, h * 0.25)
          ..quadraticBezierTo(w * 0.35, h * 0.3, w * 0.6, h * 0.12),
        branch..strokeWidth = w * 0.03,
      );
      c.drawPath(
        Path()
          ..moveTo(w * 0.3, h * 0.28)
          ..quadraticBezierTo(w * 0.45, h * 0.45, w * 0.8, h * 0.5),
        branch..strokeWidth = w * 0.018,
      );
      for (var i = 0; i < 70; i++) {
        final t = _rand(i, 9);
        final onFirst = i.isEven;
        final x = onFirst ? w * 0.6 * t : w * (0.3 + 0.5 * t);
        final y = onFirst ? h * (0.25 - 0.13 * t * t) : h * (0.28 + 0.22 * t);
        final o = Offset(x + (_rand(i, 10) - 0.5) * w * 0.1, y + (_rand(i, 11) - 0.5) * h * 0.1);
        final r = w * (0.012 + 0.012 * _rand(i, 12));
        for (var k = 0; k < 5; k++) {
          final a = k * 2 * pi / 5;
          c.drawCircle(o + Offset(cos(a), sin(a)) * r, r * 0.8, Paint()..color = const Color(0xFFFFB7C9));
        }
        c.drawCircle(o, r * 0.5, Paint()..color = const Color(0xFFE85A7E));
      }
      c.drawPath(_hill(s, h * 0.86, h * 0.03, 0.5, 2), Paint()..color = const Color(0xFF9CC9A0));
      for (var i = 0; i < 30; i++) {
        c.drawOval(
          Rect.fromCenter(
            center: Offset(_rand(i, 13) * w, h * (0.55 + 0.35 * _rand(i, 14))),
            width: w * 0.02,
            height: w * 0.012,
          ),
          Paint()..color = const Color(0xFFFFB7C9),
        );
      }
    case 7: // Desert dunes
      _sky(c, s, const [Color(0xFFFFB86B), Color(0xFFFFE6B0)], to: 0.6);
      c.drawCircle(Offset(w * 0.3, h * 0.28), w * 0.11, Paint()..color = const Color(0xFFFFF5D6));
      c.drawPath(_hill(s, h * 0.55, h * 0.06, 0.4, 1.5), Paint()..color = const Color(0xFFE8A55A));
      c.drawPath(_hill(s, h * 0.68, h * 0.07, 2.2, 1.8), Paint()..color = const Color(0xFFD48A3E));
      c.drawPath(_hill(s, h * 0.82, h * 0.06, 4.0, 2.2), Paint()..color = const Color(0xFFB86E2C));
      // Cactus.
      final cactus = Paint()..color = const Color(0xFF3F7D4E);
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.74, h * 0.6, w * 0.045, h * 0.2), Radius.circular(w)),
        cactus,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.7, h * 0.65, w * 0.03, h * 0.08), Radius.circular(w)),
        cactus,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.79, h * 0.62, w * 0.03, h * 0.07), Radius.circular(w)),
        cactus,
      );
    case 8: // Rainbow
      _sky(c, s, const [Color(0xFF64B9F2), Color(0xFFCFEFFF)]);
      const bands = [
        Color(0xFFFF5A5A),
        Color(0xFFFF9A3C),
        Color(0xFFFFD84D),
        Color(0xFF5ACF6B),
        Color(0xFF4AA8FF),
        Color(0xFF8A6CFF),
      ];
      for (var i = 0; i < bands.length; i++) {
        c.drawArc(
          Rect.fromCircle(center: Offset(w * 0.5, h * 0.95), radius: w * (0.55 - i * 0.045)),
          pi,
          pi,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.045
            ..color = bands[i],
        );
      }
      _cloud(c, Offset(w * 0.08, h * 0.88), w * 0.1, Colors.white);
      _cloud(c, Offset(w * 0.92, h * 0.88), w * 0.1, Colors.white);
      _cloud(c, Offset(w * 0.3, h * 0.15), w * 0.06, Colors.white.withValues(alpha: 0.9));
    case 9: // Autumn forest
      _sky(c, s, const [Color(0xFFFFCF8A), Color(0xFFFFF0D2)], to: 0.7);
      c.drawPath(_hill(s, h * 0.78, h * 0.03, 0.2, 2), Paint()..color = const Color(0xFF8C5A2B));
      const leaves = [Color(0xFFD9482B), Color(0xFFF08A24), Color(0xFFF5C03B), Color(0xFFB8352A), Color(0xFF9DAF3A)];
      for (var i = 0; i < 9; i++) {
        final x = w * (0.06 + i * 0.11) + (_rand(i, 15) - 0.5) * w * 0.04;
        final top = h * (0.35 + 0.15 * _rand(i, 16));
        c.drawRect(
          Rect.fromLTWH(x - w * 0.012, top + h * 0.1, w * 0.024, h * 0.8 - top),
          Paint()..color = const Color(0xFF5A3A22),
        );
        final r = w * (0.07 + 0.03 * _rand(i, 17));
        for (var k = 0; k < 4; k++) {
          c.drawCircle(
            Offset(x + (k - 1.5) * r * 0.45, top + h * 0.08 + (k.isEven ? 0 : -r * 0.4)),
            r * 0.7,
            Paint()..color = leaves[(i + k) % leaves.length],
          );
        }
      }
      for (var i = 0; i < 50; i++) {
        c.drawOval(
          Rect.fromCenter(
            center: Offset(_rand(i, 18) * w, h * (0.8 + 0.2 * _rand(i, 19))),
            width: w * 0.025,
            height: w * 0.014,
          ),
          Paint()..color = leaves[i % leaves.length],
        );
      }
    case 10: // City night
      _sky(c, s, const [Color(0xFF1A1446), Color(0xFF5B2A86), Color(0xFFE0607E)], stops: const [0, 0.55, 1]);
      c.drawCircle(Offset(w * 0.2, h * 0.18), w * 0.06, Paint()..color = const Color(0xFFFFF0C8));
      var x = 0.0;
      var i = 0;
      while (x < w) {
        final bw = w * (0.08 + 0.07 * _rand(i, 20));
        final bh = h * (0.25 + 0.4 * _rand(i, 21));
        final top = h - bh;
        c.drawRect(
          Rect.fromLTWH(x, top, bw - w * 0.006, bh),
          Paint()..color = Color.lerp(const Color(0xFF14102E), const Color(0xFF2A2152), _rand(i, 22))!,
        );
        for (var wy = top + h * 0.02; wy < h - h * 0.03; wy += h * 0.035) {
          for (var wx = x + w * 0.012; wx < x + bw - w * 0.025; wx += w * 0.025) {
            if (_rand((wx * 7 + wy * 3).round(), 23) > 0.55) {
              c.drawRect(Rect.fromLTWH(wx, wy, w * 0.012, h * 0.016), Paint()..color = const Color(0xFFFFD877));
            }
          }
        }
        x += bw;
        i++;
      }
    case 11: // Coral reef
      _sky(c, s, const [Color(0xFF3EC7E0), Color(0xFF137CB8), Color(0xFF0A3F7A)]);
      for (var i = 0; i < 6; i++) {
        c.drawPath(
          Path()
            ..moveTo(w * (0.1 + i * 0.16), 0)
            ..lineTo(w * (0.18 + i * 0.16), 0)
            ..lineTo(w * (0.05 + i * 0.16), h * 0.7)
            ..close(),
          Paint()..color = Colors.white.withValues(alpha: 0.07),
        );
      }
      c.drawPath(_hill(s, h * 0.86, h * 0.03, 1, 3), Paint()..color = const Color(0xFFE8D29A));
      const corals = [Color(0xFFFF6F61), Color(0xFFFF9EC4), Color(0xFFFFB347), Color(0xFFB58CFF)];
      for (var i = 0; i < 7; i++) {
        final bx = w * (0.08 + i * 0.14);
        final col = corals[i % corals.length];
        final p = Paint()
          ..color = col
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = w * 0.022;
        final hgt = h * (0.15 + 0.12 * _rand(i, 24));
        c.drawLine(Offset(bx, h * 0.88), Offset(bx, h * 0.88 - hgt), p);
        c.drawLine(Offset(bx, h * 0.88 - hgt * 0.5), Offset(bx - w * 0.05, h * 0.88 - hgt * 0.8), p);
        c.drawLine(Offset(bx, h * 0.88 - hgt * 0.4), Offset(bx + w * 0.05, h * 0.88 - hgt * 0.75), p);
      }
      for (final (fx, fy, col) in const [
        (0.3, 0.35, Color(0xFFFFC93C)),
        (0.65, 0.5, Color(0xFFFF7A45)),
        (0.5, 0.22, Color(0xFF7CF0C8)),
      ]) {
        final o = Offset(w * fx, h * fy);
        c.drawOval(Rect.fromCenter(center: o, width: w * 0.12, height: h * 0.06), Paint()..color = col);
        c.drawPath(
          Path()
            ..moveTo(o.dx + w * 0.05, o.dy)
            ..lineTo(o.dx + w * 0.1, o.dy - h * 0.03)
            ..lineTo(o.dx + w * 0.1, o.dy + h * 0.03)
            ..close(),
          Paint()..color = col,
        );
        c.drawCircle(o + Offset(-w * 0.03, -h * 0.005), w * 0.008, Paint()..color = Colors.black87);
      }
      for (var i = 0; i < 25; i++) {
        c.drawCircle(
          Offset(w * (0.75 + 0.15 * _rand(i, 25)), h * (0.1 + 0.6 * _rand(i, 26))),
          w * (0.006 + 0.01 * _rand(i, 27)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.003
            ..color = Colors.white.withValues(alpha: 0.7),
        );
      }
  }
  c.restore();
}

/// Small preview used in the picture picker.
class ScenePainter extends CustomPainter {
  final int index;
  ScenePainter(this.index);

  @override
  void paint(Canvas canvas, Size size) => paintScene(canvas, size, index);

  @override
  bool shouldRepaint(covariant ScenePainter old) => old.index != index;
}

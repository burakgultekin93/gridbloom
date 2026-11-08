import 'dart:math';

import 'package:flutter/material.dart';

import '../game/game_state.dart';

/// Background colours along the heat scale: ice, garden, warm, fire.
const _stops = <double>[0, 0.35, 0.7, 1];
const _topColors = <Color>[Color(0xFFDDEEF8), Color(0xFFF6F1E7), Color(0xFFFFD6A0), Color(0xFFF0642C)];
const _bottomColors = <Color>[Color(0xFFB9D7EC), Color(0xFFEFE4CF), Color(0xFFF7A260), Color(0xFF8E1F12)];

Color _along(List<Color> colors, double h) {
  for (var i = 0; i < _stops.length - 1; i++) {
    if (h <= _stops[i + 1]) {
      final t = (h - _stops[i]) / (_stops[i + 1] - _stops[i]);
      return Color.lerp(colors[i], colors[i + 1], t)!;
    }
  }
  return colors.last;
}

Color heatTop(double h) => _along(_topColors, h);
Color heatBottom(double h) => _along(_bottomColors, h);

/// Text on the background: dark soil on light, cream on fire.
Color heatInk(double h) =>
    Color.lerp(const Color(0xFF5B4636), const Color(0xFFFFF4E0), ((h - 0.6) / 0.25).clamp(0.0, 1.0))!;

String heatLabel(double h) {
  if (h <= 0) return 'Soğuk';
  if (h < 0.35) return 'Ilık';
  if (h < 0.7) return 'Sıcak';
  if (h < 1) return 'Kızgın';
  return 'Alev!';
}

/// Snow when cold, rising embers and flames when hot, and a full blaze
/// for a short while after the whole board is cleared.
class HeatEffectsPainter extends CustomPainter {
  final double heat;
  final double seconds;
  final double blaze; // 0..1, fades out after a board clear

  HeatEffectsPainter({required this.heat, required this.seconds, required this.blaze});

  static double _rand(int i, int salt) {
    final x = sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    _snow(canvas, size);
    final fire = max(((heat - 0.5) / 0.5).clamp(0.0, 1.0), blaze);
    if (fire > 0) {
      _flames(canvas, size, fire);
      _embers(canvas, size, fire);
    }
  }

  void _snow(Canvas canvas, Size size) {
    final amount = ((0.3 - heat) / 0.3).clamp(0.0, 1.0) * (1 - blaze);
    if (amount <= 0) return;
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.85 * amount);
    for (var i = 0; i < 40; i++) {
      final speed = 18 + _rand(i, 1) * 30;
      final y = (_rand(i, 2) * size.height + seconds * speed) % (size.height + 20) - 10;
      final x = _rand(i, 3) * size.width + sin(seconds * 0.8 + i) * 12;
      canvas.drawCircle(Offset(x, y), 1.5 + _rand(i, 4) * 2.5, paint);
    }
  }

  void _flames(Canvas canvas, Size size, double fire) {
    final base = size.height;
    final maxH = size.height * (0.10 + 0.22 * fire);
    const tongues = 18;
    for (var layer = 0; layer < 3; layer++) {
      final color = [const Color(0xFFD7301F), const Color(0xFFF47B20), const Color(0xFFFFC94A)][layer];
      final paint = Paint()..color = color.withValues(alpha: (0.55 + 0.15 * layer) * fire);
      final shrink = 1 - layer * 0.3;
      final path = Path()..moveTo(0, base);
      for (var i = 0; i <= tongues; i++) {
        final x = size.width * i / tongues;
        final flicker = 0.6 + 0.4 * sin(seconds * (5 + _rand(i, 5) * 4) + i * 1.7 + layer);
        final h = maxH * shrink * flicker * (0.6 + 0.4 * _rand(i, 6 + layer));
        final prevX = size.width * (i - 0.5) / tongues;
        path.quadraticBezierTo(prevX, base - h * 0.3, x, base - h);
      }
      path
        ..lineTo(size.width, base)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  void _embers(Canvas canvas, Size size, double fire) {
    final count = (14 + 36 * fire).round();
    for (var i = 0; i < count; i++) {
      final speed = 40 + _rand(i, 7) * 90;
      final travel = size.height * 0.85;
      final y = size.height - (_rand(i, 8) * travel + seconds * speed) % travel;
      final life = 1 - (size.height - y) / travel;
      final x = _rand(i, 9) * size.width + sin(seconds * 2 + i) * 10;
      final c = Color.lerp(const Color(0xFFFFE08A), const Color(0xFFFF5A1F), _rand(i, 10))!;
      canvas.drawCircle(Offset(x, y), 1.5 + 2.5 * _rand(i, 11), Paint()..color = c.withValues(alpha: life * fire));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// A short cheer for a good move, or null for an ordinary one.
String? praiseFor(MoveResult r) {
  if (r.boardCleared) return 'Bahçe tertemiz!';
  if (r.linesCleared >= 5) return 'İnanılmaz!';
  if (r.linesCleared == 4) return 'Efsane!';
  if (r.linesCleared == 3) return 'Muhteşem!';
  if (r.multiplier >= 6) return 'Yanıyorsun!';
  if (r.multiplier >= 4) return 'Durdurulamaz!';
  if (r.linesCleared == 2) return 'Harika!';
  if (r.multiplier >= 2) return 'Süper!';
  if (r.linesCleared == 1) return 'Güzel!';
  return null;
}

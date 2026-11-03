import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'sky.dart';
import 'theme.dart';

String formatGrams(int g) {
  if (g < 1000) return '$g g';
  final kg = g / 1000;
  var text = kg.toStringAsFixed(kg < 10 ? 2 : 1);
  // 2.50 -> 2.5, 10.0 -> 10
  text = text.replaceFirst(RegExp(r'\.?0+$'), '');
  return '$text kg';
}

String teaspoons(int g) {
  final t = g / 4;
  final whole = t.floor();
  final frac = t - whole;
  final half = frac >= 0.25 && frac < 0.75;
  final n = frac >= 0.75 ? whole + 1 : whole;
  final text = half ? (n == 0 ? '½' : '$n½') : '$n';
  return '$text ${t <= 1 ? 'teaspoon' : 'teaspoons'}';
}

const _grainColors = [Color(0xFFFFFFFF), Color(0xFFF4F2FA), Color(0xFFE6E1F2), Color(0xFFD4CDE6), Color(0xFFBDB4D6)];
const _maxGrains = 2600;
const _grainSize = 2.6;

/// Height of a sugar pile at t in -1..1, as a share of its peak.
double moundAt(double t) => t.abs() >= 1 ? 0 : pow(1 - t * t, 1.35).toDouble();

class _Grain {
  const _Grain(this.x, this.y, this.angle, this.scale, this.color, this.rank);
  final double x; // -0.5..0.5 of the pile's width
  final double y; // 0..1 of the pile's height, from the floor
  final double angle;
  final double scale;
  final Color color;

  /// Order of creation: the first n grains are an even sample of the pile.
  final int rank;
}

/// One fixed set of grains, bottom first, so a pile only ever gains grains as
/// it grows and never reshuffles.
final List<_Grain> _grains = () {
  final r = Random(5);
  final g = <_Grain>[];
  while (g.length < _maxGrains) {
    final x = r.nextDouble() - 0.5;
    final top = moundAt(x * 2);
    if (top <= 0) continue;
    final y = r.nextDouble() * top;
    // Denser near the surface, so it reads as a heap rather than a blob.
    if (r.nextDouble() > 0.35 + 0.65 * sqrt(y / top)) continue;
    g.add(_Grain(x, y, r.nextDouble() * pi / 2, const [0.7, 0.85, 1.0, 1.0, 1.15][r.nextInt(5)], _grainColors[r.nextInt(_grainColors.length)], g.length));
  }
  g.sort((a, b) => a.y.compareTo(b.y));
  return g;
}();

/// Grams eaten as a pile of real-looking grains, inside a dashed gold outline
/// of the pile it would have been at the old habit.
class GrainPilePainter extends CustomPainter {
  GrainPilePainter({required this.grams, this.ghostGrams, this.ghostLabel, this.reference, this.progress = 1, this.floorStar = false});

  final int grams;

  /// What would have been eaten. Null hides the outline.
  final int? ghostGrams;
  final String? ghostLabel;

  /// Grams that fill the scene when there is no outline.
  final int? reference;

  /// 0..1: grains appear bottom-up, for the settle-in animation.
  final double progress;

  /// A small star where the pile would be, for a clean period.
  final bool floorStar;

  static const _aspect = 0.68;

  @override
  void paint(Canvas canvas, Size size) {
    final floor = size.height - 8;
    final labelSpace = ghostLabel == null ? 0.0 : 30.0;
    final maxW = min(size.width - 24, (size.height - 8 - labelSpace) / _aspect);
    final full = max(1, max(ghostGrams ?? 0, max(grams, reference ?? grams)));
    double widthFor(int g) => maxW * sqrt(g / full);
    final cx = size.width / 2;

    canvas.drawLine(Offset(12, floor + 1), Offset(size.width - 12, floor + 1), Paint()..color = C.line);

    final ghost = ghostGrams;
    if (ghost != null && ghost > 0) {
      final w = widthFor(ghost);
      final h = w * _aspect;
      final path = Path()..moveTo(cx - w / 2, floor);
      for (var i = 0; i <= 80; i++) {
        final t = -1 + i / 40;
        path.lineTo(cx + t * w / 2, floor - moundAt(t) * h);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [C.gold.withValues(alpha: 0.09), C.gold.withValues(alpha: 0)],
          ).createShader(Rect.fromLTWH(cx - w / 2, floor - h, w, h)),
      );
      _dashed(
        canvas,
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = C.gold.withValues(alpha: 0.7),
      );
      if (ghostLabel != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: ghostLabel,
            style: T.body(12, color: C.gold, height: 1),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout(maxWidth: size.width - 24);
        tp.paint(canvas, Offset(cx - tp.width / 2, max(0, floor - h - 22)));
      }
    }

    if (grams <= 0) {
      if (floorStar) paintStar(canvas, Offset(cx, floor - 14), 9, C.gold);
      return;
    }

    final w = max(12.0, widthFor(grams));
    final h = w * _aspect;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, floor - h * 0.3), width: w * 1.7, height: h * 1.3),
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFFC9BEF0).withValues(alpha: 0.3), const Color(0xFFC9BEF0).withValues(alpha: 0)],
        ).createShader(Rect.fromCenter(center: Offset(cx, floor - h * 0.3), width: w * 1.7, height: h * 1.3)),
    );
    // Enough grains to fill the area, at a fixed grain size.
    final n = min(_maxGrains, max(8, w * h / (_grainSize * _grainSize))).round();
    // Bottom-up, so the pile settles in as [progress] runs.
    final shown = _grains.where((g) => g.rank < n && g.y <= progress.clamp(0.0, 1.0)).toList();
    _paintGrains(canvas, [for (final g in shown) Offset(cx + g.x * w, floor - g.y * h)], shown);
  }

  static void _dashed(Canvas canvas, Path path, Paint paint) {
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, min(d + 4, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(GrainPilePainter o) =>
      o.grams != grams ||
      o.ghostGrams != ghostGrams ||
      o.progress != progress ||
      o.ghostLabel != ghostLabel ||
      o.reference != reference ||
      o.floorStar != floorStar;
}

/// Draws grains as small rotated squares in one call.
void _paintGrains(Canvas canvas, List<Offset> at, List<_Grain> grains, {double opacity = 1}) {
  if (at.isEmpty) return;
  final pos = Float32List(at.length * 12);
  final colors = Int32List(at.length * 6);
  for (var i = 0; i < at.length; i++) {
    final g = grains[i];
    final s = _grainSize * g.scale / 2;
    final c = cos(g.angle) * s, sn = sin(g.angle) * s;
    final p = at[i];
    final corners = [p + Offset(-c + sn, -sn - c), p + Offset(c + sn, sn - c), p + Offset(c - sn, sn + c), p + Offset(-c - sn, -sn + c)];
    final tri = [corners[0], corners[1], corners[2], corners[0], corners[2], corners[3]];
    for (var k = 0; k < 6; k++) {
      pos[i * 12 + k * 2] = tri[k].dx;
      pos[i * 12 + k * 2 + 1] = tri[k].dy;
      colors[i * 6 + k] = g.color.withValues(alpha: opacity).toARGB32();
    }
  }
  canvas.drawVertices(ui.Vertices.raw(ui.VertexMode.triangles, pos, colors: colors), BlendMode.dst, Paint());
}

/// A teaspoon tipping grains into a stream while [pouring].
class SpoonPainter extends CustomPainter {
  SpoonPainter({required this.time, required this.pouring, required this.streamTo});
  final double time;
  final bool pouring;

  /// Where the stream lands, in this painter's coordinates.
  final Offset streamTo;

  @override
  void paint(Canvas canvas, Size size) {
    final bowl = Offset(size.width * 0.58, 70);
    final tilt = pouring ? 0.32 : 0.08;
    canvas.save();
    canvas.translate(bowl.dx, bowl.dy);
    canvas.rotate(tilt);
    canvas.drawLine(
      const Offset(-30, -2),
      const Offset(-150, -8),
      Paint()
        ..color = const Color(0xFF8C94B5)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 60, height: 34), Paint()..color = const Color(0xFFC3C8DC));
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, -1), width: 52, height: 26), Paint()..color = const Color(0xFF7C84A6));
    final heap = [for (var i = 0; i < 90; i++) _grains[i * 7]];
    _paintGrains(canvas, [for (final g in heap) Offset(g.x * 44, 6 - g.y * 12)], heap);
    canvas.restore();

    if (!pouring) return;
    final lip = bowl + Offset(cos(tilt) * 26, sin(tilt) * 26 + 10);
    final r = Random(9);
    final at = <Offset>[];
    final grains = <_Grain>[];
    for (var i = 0; i < 150; i++) {
      // Each grain falls on its own phase, accelerating as it drops.
      final t = (time * 0.9 + r.nextDouble()) % 1;
      final y = lip.dy + (streamTo.dy - lip.dy) * t * t;
      final x = lip.dx + (streamTo.dx - lip.dx) * t + (r.nextDouble() - 0.5) * (3 + 12 * t);
      at.add(Offset(x, y));
      grains.add(_grains[(i * 13) % _maxGrains]);
    }
    _paintGrains(canvas, at, grains, opacity: 0.9);
  }

  @override
  bool shouldRepaint(SpoonPainter o) => true;
}

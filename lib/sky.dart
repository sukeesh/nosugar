import 'dart:math';

import 'package:flutter/material.dart';

import 'state.dart';
import 'theme.dart';

/// Draws the sugar crystal: a hexagonal prism seen from above-front, three faces.
/// [center] is the middle of the shape, [size] its height.
void paintCrystal(Canvas canvas, Offset center, double size, {double opacity = 1, double melt = 0}) {
  final s = size / 54;
  Offset p(double x, double y) => center + Offset((x - 24) * s, (y - 27) * s);
  // [melt] sinks the top face so the crystal looks like it is dissolving.
  final topY = 2 + 12 * melt;
  final paint = Paint()..isAntiAlias = true;
  Path face(List<Offset> pts) => Path()..addPolygon(pts, true);
  paint.color = C.crystalTop.withValues(alpha: opacity);
  canvas.drawPath(face([p(24, topY), p(44, 13), p(24, 24), p(4, 13)]), paint);
  paint.color = C.crystalLeft.withValues(alpha: opacity);
  canvas.drawPath(face([p(4, 13), p(24, 24), p(24, 52), p(4, 41)]), paint);
  paint.color = C.crystalRight.withValues(alpha: opacity);
  canvas.drawPath(face([p(24, 24), p(44, 13), p(44, 41), p(24, 52)]), paint);
}

void paintStar(Canvas canvas, Offset c, double r, Color color) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final rad = i.isEven ? r : r * 0.45;
    final a = -pi / 2 + i * pi / 5;
    final pt = c + Offset(cos(a) * rad, sin(a) * rad);
    i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
  }
  path.close();
  canvas.drawPath(path, Paint()..color = color);
}

class CrystalIcon extends StatelessWidget {
  const CrystalIcon({super.key, this.size = 40, this.melt = 0, this.opacity = 1});
  final double size;
  final double melt;
  final double opacity;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size * 48 / 54,
    height: size,
    child: CustomPaint(painter: _CrystalPainter(size, melt, opacity)),
  );
}

class _CrystalPainter extends CustomPainter {
  _CrystalPainter(this.s, this.melt, this.opacity);
  final double s, melt, opacity;
  @override
  void paint(Canvas canvas, Size size) => paintCrystal(canvas, size.center(Offset.zero), s, melt: melt, opacity: opacity);
  @override
  bool shouldRepaint(_CrystalPainter o) => o.melt != melt || o.opacity != opacity;
}

/// A random walk that stays compact, so a constellation looks drawn rather
/// than scattered. Returns [count] points in unnormalised space.
List<Offset> walk(int seed, int count) {
  final rnd = Random(seed);
  var pos = Offset.zero;
  var heading = rnd.nextDouble() * 2 * pi;
  final pts = <Offset>[pos];
  for (var i = 1; i < count; i++) {
    heading += (rnd.nextDouble() - 0.5) * 1.6;
    final limit = 1.6 + sqrt(i.toDouble()) * 0.9;
    if (pos.distance > limit) {
      final home = atan2(-pos.dy, -pos.dx);
      var diff = (home - heading) % (2 * pi);
      if (diff > pi) diff -= 2 * pi;
      heading += diff * 0.6;
    }
    final step = 0.75 + rnd.nextDouble() * 0.5;
    pos += Offset(cos(heading) * step, sin(heading) * step);
    pts.add(pos);
  }
  return pts;
}

/// Fits points into [rect], preserving aspect, with a cap on how far apart
/// neighbours can be so a 3-star constellation doesn't sprawl over the sky.
List<Offset> fit(List<Offset> pts, Rect rect, {double maxUnit = 46}) {
  if (pts.length == 1) return [rect.center];
  var minX = pts.first.dx, maxX = minX, minY = pts.first.dy, maxY = minY;
  for (final p in pts) {
    minX = min(minX, p.dx);
    maxX = max(maxX, p.dx);
    minY = min(minY, p.dy);
    maxY = max(maxY, p.dy);
  }
  final w = max(maxX - minX, 0.001), h = max(maxY - minY, 0.001);
  final scale = min(maxUnit, min(rect.width / w, rect.height / h));
  final mid = Offset((minX + maxX) / 2, (minY + maxY) / 2);
  return pts.map((p) => rect.center + (p - mid) * scale).toList();
}

double _starRadius(int seed, int i, double base) {
  final r = Random(seed * 31 + i);
  final big = (i + 1) % 7 == 0;
  return base * (big ? 1.5 : 0.75 + r.nextDouble() * 0.5);
}

/// The constellation: lit stars joined by a faint line, optionally with the
/// next crystal waiting at the end of the walk.
class SkyPainter extends CustomPainter {
  SkyPainter({
    required this.constellation,
    this.showCrystal = false,
    this.endCrystal = false,
    this.twinkle = 0,
    this.background = true,
    this.starBase = 2.4,
    this.padding = const EdgeInsets.all(28),
    this.maxUnit = 46,
    this.lineColor = C.gold,
    this.starColor = C.gold,
    this.shootingStars = 0,
    this.cometTime,
    this.freshAge,
  });

  final Constellation constellation;
  final bool showCrystal;
  final bool endCrystal;
  final double twinkle;
  final bool background;
  final double starBase;
  final EdgeInsets padding;
  final double maxUnit;
  final Color lineColor;
  final Color starColor;
  final int shootingStars;

  /// Seconds on a running clock; null draws comets as still trails.
  final double? cometTime;

  /// Seconds since a craving was just outlasted, to play its comet now.
  final double? freshAge;

  @override
  void paint(Canvas canvas, Size size) {
    if (background) _paintBackground(canvas, size);

    final n = constellation.length;
    final total = n + (showCrystal || endCrystal ? 1 : 0);
    if (total == 0) return;
    final rect = padding.deflateRect(Offset.zero & size);
    final pts = fit(walk(constellation.seed, total), rect, maxUnit: maxUnit);

    if (n > 1) {
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < n; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = lineColor.withValues(alpha: 0.35),
      );
    }

    for (var i = 0; i < n; i++) {
      final moon = constellation.nights[i] == Night.moon;
      final r = _starRadius(constellation.seed, i, starBase);
      final color = moon ? C.moon : starColor;
      if (r > starBase * 1.2 && background) {
        canvas.drawCircle(pts[i], r * 3.5, Paint()..color = color.withValues(alpha: 0.08));
      }
      canvas.drawCircle(pts[i], moon ? r * 0.8 : r, Paint()..color = color);
    }

    if (total > n) {
      final c = pts.last;
      if (n > 0) {
        _dashedLine(canvas, pts[n - 1], c, C.crystalLeft.withValues(alpha: 0.5));
      }
      final crystalSize = starBase * 9;
      if (showCrystal) {
        final pulse = 0.5 + 0.5 * sin(twinkle * 2 * pi);
        canvas.drawCircle(c, crystalSize * (0.9 + pulse * 0.25), Paint()..color = C.crystalLeft.withValues(alpha: 0.06 + 0.06 * pulse));
      }
      paintCrystal(canvas, c, crystalSize);
    }
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final d = b - a;
    final len = d.distance;
    if (len == 0) return;
    final dir = d / len;
    // Stop short so the dash doesn't run into the crystal.
    final stop = max(0.0, len - starBase * 6);
    for (double t = 0; t < stop; t += 7) {
      canvas.drawLine(a + dir * t, a + dir * min(t + 3, stop), paint);
    }
  }

  void _paintBackground(Canvas canvas, Size size) {
    final rnd = Random(7);
    for (var i = 0; i < 46; i++) {
      final p = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      final phase = rnd.nextDouble();
      final a = 0.25 + 0.35 * (0.5 + 0.5 * sin((twinkle + phase) * 2 * pi));
      canvas.drawCircle(p, 0.6 + rnd.nextDouble() * 0.8, Paint()..color = C.soft.withValues(alpha: a * 0.6));
    }
    _paintComets(canvas, size);
  }

  /// Shooting stars: one per craving outlasted in this constellation (up to 5).
  /// With [cometTime] they take turns streaking across; without it they sit
  /// still as faint trails. [freshAge] plays the newest one right away.
  void _paintComets(Canvas canvas, Size size) {
    final n = min(shootingStars, 5);
    if (n == 0) return;
    final srnd = Random(constellation.seed + 99);
    const dir = Offset(-0.91, 0.41);
    const slot = 3.2, life = 1.3;
    for (var i = 0; i < n; i++) {
      final start = Offset(srnd.nextDouble() * size.width * 0.7 + size.width * 0.25, srnd.nextDouble() * size.height * 0.5);
      final travel = 90 + srnd.nextDouble() * 50;
      if (cometTime == null) {
        _comet(canvas, start + dir * travel, dir, 26 + travel * 0.1, 0.9, 1.4);
        continue;
      }
      final newest = i == n - 1;
      double? age;
      if (newest && freshAge != null && freshAge! < life * 1.6) {
        age = freshAge! / 1.6;
      } else {
        final local = (cometTime! - i * slot) % (n * slot + 1.5);
        if (local < life) age = local;
      }
      if (age == null) continue;
      final p = age / life;
      final head = start + dir * travel * Curves.easeOutCubic.transform(p);
      final fresh = newest && freshAge != null && freshAge! < life * 1.6;
      _comet(canvas, head, dir, (fresh ? 70 : 46) * (1 - p * 0.4), sin(pi * p), fresh ? 2.2 : 1.6);
    }
  }

  void _comet(Canvas canvas, Offset head, Offset dir, double tail, double alpha, double width) {
    if (alpha <= 0) return;
    final end = head - dir * tail;
    canvas.drawLine(
      head,
      end,
      Paint()
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            C.sos.withValues(alpha: 0.95 * alpha),
            C.sos.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromPoints(head, end)),
    );
    canvas.drawCircle(head, width * 3, Paint()..color = C.sos.withValues(alpha: 0.18 * alpha));
    canvas.drawCircle(head, width * 0.9, Paint()..color = Colors.white.withValues(alpha: alpha));
  }

  @override
  // The constellation is mutated in place, so we can't diff it cheaply.
  bool shouldRepaint(SkyPainter o) => true;
}

/// Small fixed sky used in cards.
class MiniSky extends StatelessWidget {
  const MiniSky({super.key, required this.constellation, this.current = false, this.height = 90});
  final Constellation constellation;
  final bool current;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: SkyPainter(
          constellation: constellation,
          background: false,
          endCrystal: constellation.endedByCrystal,
          starBase: 1.8,
          padding: const EdgeInsets.all(8),
          maxUnit: 22,
          lineColor: current ? C.gold : C.soft,
          starColor: current ? C.gold : C.text,
        ),
      ),
    );
  }
}

/// Crystal shards bursting out and collapsing into a star. t runs 0..1.
class BurstPainter extends CustomPainter {
  BurstPainter(this.t, {this.seed = 3});
  final double t;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final unit = size.shortestSide;
    // 0 .. .3 crystal trembles, .3 .. .55 shards fly out, .55 .. 1 they fall into a star.
    if (t < 0.3) {
      final k = t / 0.3;
      final shake = sin(k * 40) * 2.5 * k;
      canvas.drawCircle(c, unit * 0.22, Paint()..color = C.crystalLeft.withValues(alpha: 0.05 + 0.1 * k));
      paintCrystal(canvas, c + Offset(shake, 0), unit * 0.3 * (1 + 0.08 * k));
      return;
    }
    final rnd = Random(seed);
    final out = Curves.easeOutCubic.transform(((t - 0.3) / 0.25).clamp(0, 1));
    final back = Curves.easeInCubic.transform(((t - 0.55) / 0.25).clamp(0, 1));
    for (var i = 0; i < 14; i++) {
      final a = i / 14 * 2 * pi + rnd.nextDouble() * 0.4;
      final dist = unit * (0.22 + rnd.nextDouble() * 0.22);
      final d = dist * out * (1 - back);
      final p = c + Offset(cos(a) * d, sin(a) * d);
      final s = unit * (0.018 + rnd.nextDouble() * 0.02) * (1 - back * 0.7);
      final col = i.isEven ? C.crystalTop : C.crystalLeft;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(a + t * 6);
      canvas.drawPath(
        Path()..addPolygon([Offset(-s, -s * 0.6), Offset(s, -s * 0.2), Offset(-s * 0.2, s)], true),
        Paint()..color = Color.lerp(col, C.gold, back)!.withValues(alpha: 1 - back * 0.6),
      );
      canvas.restore();
    }
    final grow = Curves.elasticOut.transform(((t - 0.68) / 0.32).clamp(0, 1));
    if (grow > 0) {
      final glowR = unit * 0.5 * grow.clamp(0.0, 1.2);
      canvas.drawCircle(
        c,
        glowR,
        Paint()
          ..shader = RadialGradient(
            colors: [C.gold.withValues(alpha: 0.35), C.gold.withValues(alpha: 0.08), C.gold.withValues(alpha: 0)],
            stops: const [0, 0.45, 1],
          ).createShader(Rect.fromCircle(center: c, radius: glowR)),
      );
      paintStar(canvas, c, unit * 0.17 * grow, C.gold);
    }
  }

  @override
  bool shouldRepaint(BurstPainter o) => o.t != t;
}

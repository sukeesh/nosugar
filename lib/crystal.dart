import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Size names for the cluster as logged sugar grows.
class ClusterLevel {
  const ClusterLevel(this.name, this.grams);
  final String name;
  final int grams;
}

const clusterLevels = [
  ClusterLevel('Shard', 0),
  ClusterLevel('Cluster', 250),
  ClusterLevel('Geode', 2500),
  ClusterLevel('Cavern', 10000),
];

ClusterLevel levelFor(int grams) => clusterLevels.lastWhere((l) => grams >= l.grams);
ClusterLevel? nextLevel(int grams) {
  for (final l in clusterLevels) {
    if (l.grams > grams) return l;
  }
  return null;
}

/// Everyday things of a known-ish weight, so kilograms mean something.
const _weights = [
  (150, 'an apple'),
  (500, 'a loaf of bread'),
  (1000, 'a pineapple'),
  (2000, 'a 2-litre bottle of water'),
  (3500, 'a newborn baby'),
  (4500, 'a house cat'),
  (7000, 'a bowling ball'),
  (10000, 'a car tyre'),
  (20000, 'a checked suitcase'),
  (30000, 'a Labrador'),
];

/// "about as heavy as a pineapple", picking the closest by ratio.
String? weighsLike(int grams) {
  if (grams < 100) return null;
  var best = _weights.first;
  for (final w in _weights) {
    if ((log(grams / w.$1)).abs() < (log(grams / best.$1)).abs()) best = w;
  }
  return 'about as heavy as ${best.$2}';
}

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

String packets(int g) {
  final p = g / 1000;
  final quarters = (p * 4).round();
  final whole = quarters ~/ 4;
  final rest = ['', '¼', '½', '¾'][quarters % 4];
  if (whole == 0 && rest.isEmpty) return 'less than a quarter packet';
  final n = whole == 0 ? rest : '$whole$rest';
  return '$n ${quarters <= 4 ? 'packet' : 'packets'}';
}

/// One crystal in the cluster: base point, lean, size.
class _Spike {
  _Spike(this.dx, this.angle, this.scale);
  final double dx, angle, scale;
}

/// Crystals fan out from the middle, larger ones in the centre. The layout
/// depends only on how many there are, so it stays stable as the cluster grows.
List<_Spike> _spikes(int count) {
  final rnd = Random(42);
  final out = <_Spike>[];
  for (var i = 0; i < count; i++) {
    final side = i == 0 ? 0 : (i.isOdd ? -1 : 1);
    final ring = (i + 1) ~/ 2;
    final angle = side * (0.28 + ring * 0.16 + rnd.nextDouble() * 0.08);
    final scale = max(0.28, 1 - ring * 0.13 - rnd.nextDouble() * 0.08);
    out.add(_Spike(side * (ring * 10.0 + rnd.nextDouble() * 6), angle.clamp(-1.2, 1.2), scale));
  }
  return out;
}

int crystalCount(int grams) => (1 + sqrt(max(0, grams) / 20)).floor().clamp(1, 17);

/// Faceted sugar crystals rising from a rock. [grow] (0..1) animates the newest
/// crystal in; [highlightNewest] outlines it.
class ClusterPainter extends CustomPainter {
  ClusterPainter({required this.grams, this.grow = 1, this.highlightNewest = false, this.sparkle = 0});
  final int grams;
  final double grow;
  final bool highlightNewest;
  final double sparkle;

  @override
  void paint(Canvas canvas, Size size) {
    final count = crystalCount(grams);
    final spikes = _spikes(count);
    // The whole cluster gets bigger with sugar, slowly.
    final overall = 0.55 + 0.45 * (log(1 + grams / 50) / log(1 + 10000 / 50)).clamp(0.0, 1.0);
    final base = Offset(size.width / 2, size.height * 0.92);
    final unit = min(size.height / 190, size.width / 230) * overall;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(base.dx, size.height * 0.55), width: size.width * 0.95, height: size.height * 0.95),
      Paint()
        ..shader = RadialGradient(colors: [const Color(0xFFB9A8F0).withValues(alpha: 0.32), const Color(0x00B9A8F0)])
            .createShader(Rect.fromCenter(center: Offset(base.dx, size.height * 0.55), width: size.width * 0.95, height: size.height * 0.95)),
    );

    // Draw small outer spikes first so the big middle ones sit in front of them.
    final order = List.generate(count, (i) => i)..sort((a, b) => spikes[a].scale.compareTo(spikes[b].scale));
    for (final i in order) {
      final s = spikes[i];
      final newest = i == count - 1;
      final g = newest ? Curves.easeOutBack.transform(grow.clamp(0, 1)) : 1.0;
      if (g <= 0) continue;
      _prism(canvas, base + Offset(s.dx * unit, 0), s.angle, s.scale * unit * g, outline: newest && highlightNewest);
    }

    // The rock the crystals grow from.
    final w = 90 * unit + 40;
    final rock = Path()
      ..moveTo(base.dx - w, base.dy + 8)
      ..lineTo(base.dx - w * 0.62, base.dy - 10)
      ..lineTo(base.dx - w * 0.2, base.dy - 4)
      ..lineTo(base.dx, base.dy - 12)
      ..lineTo(base.dx + w * 0.3, base.dy - 4)
      ..lineTo(base.dx + w * 0.66, base.dy - 10)
      ..lineTo(base.dx + w, base.dy + 8)
      ..close();
    canvas.drawPath(rock, Paint()..color = const Color(0xFF1A2036));
    canvas.drawPath(
      Path()
        ..moveTo(base.dx - w * 0.62, base.dy - 10)
        ..lineTo(base.dx - w * 0.2, base.dy - 4)
        ..lineTo(base.dx - w * 0.36, base.dy + 8)
        ..close(),
      Paint()..color = const Color(0xFF232A44),
    );

    if (sparkle > 0) {
      final rnd = Random(9);
      for (var i = 0; i < 7; i++) {
        final t = (sparkle + i / 7) % 1.0;
        final p = Offset(base.dx + (rnd.nextDouble() - 0.5) * size.width * 0.7, size.height * (0.75 - 0.6 * t - rnd.nextDouble() * 0.1));
        _sparkle(canvas, p, 3 + 4 * (1 - t), (1 - t) * 0.9);
      }
    }
  }

  void _prism(Canvas canvas, Offset base, double angle, double s, {bool outline = false}) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(angle);
    canvas.scale(s);
    Path poly(List<Offset> p) => Path()..addPolygon(p, true);
    Paint grad(Color a, Color b, {bool diagonal = false}) => Paint()
      ..shader = LinearGradient(
        begin: diagonal ? Alignment.topLeft : Alignment.topCenter,
        end: diagonal ? Alignment.bottomRight : Alignment.bottomCenter,
        colors: [a, b],
      ).createShader(const Rect.fromLTRB(-20, -160, 20, 0));
    canvas.drawPath(poly(const [Offset(-20, -120), Offset(0, -108), Offset(0, 0), Offset(-20, -10)]), grad(const Color(0xFFFAF7FE), const Color(0xFFC9BEE6)));
    canvas.drawPath(poly(const [Offset(0, -108), Offset(20, -120), Offset(20, -10), Offset(0, 0)]), grad(const Color(0xFFB7A9DE), const Color(0xFF7E70A8)));
    canvas.drawPath(poly(const [Offset(-20, -120), Offset(0, -160), Offset(0, -108)]), grad(Colors.white, const Color(0xFFE4DCF5), diagonal: true));
    canvas.drawPath(poly(const [Offset(0, -160), Offset(20, -120), Offset(0, -108)]), grad(const Color(0xFFD8CEF0), const Color(0xFF9C8EC6), diagonal: true));
    canvas.drawLine(const Offset(-17, -116), const Offset(-17, -14), Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1.5);
    if (outline) {
      canvas.drawPath(
        poly(const [Offset(-20, -120), Offset(0, -160), Offset(20, -120), Offset(20, -10), Offset(0, 0), Offset(-20, -10)]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 / s
          ..color = Colors.white.withValues(alpha: 0.9),
      );
    }
    canvas.restore();
  }

  void _sparkle(Canvas canvas, Offset c, double r, double alpha) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.3, c.dy - r * 0.3)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx + r * 0.3, c.dy + r * 0.3)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * 0.3, c.dy + r * 0.3)
      ..lineTo(c.dx - r, c.dy)
      ..lineTo(c.dx - r * 0.3, c.dy - r * 0.3)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: alpha));
  }

  @override
  bool shouldRepaint(ClusterPainter o) => o.grams != grams || o.grow != grow || o.sparkle != sparkle || o.highlightNewest != highlightNewest;
}

class Cluster extends StatelessWidget {
  const Cluster({super.key, required this.grams, this.height = 220, this.grow = 1, this.highlightNewest = false, this.sparkle = 0});
  final int grams;
  final double height;
  final double grow;
  final bool highlightNewest;
  final double sparkle;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: ClusterPainter(grams: grams, grow: grow, highlightNewest: highlightNewest, sparkle: sparkle)),
      );
}

/// A 1 kg sugar packet. [fill] 0..1; [ghost] draws a dashed gold outline.
class PacketPainter extends CustomPainter {
  PacketPainter({this.fill = 1, this.ghost = false});
  final double fill;
  final bool ghost;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final body = RRect.fromLTRBR(0, h * 0.14, w, h, Radius.circular(w * 0.13));
    final crimp = Path()..moveTo(w * 0.04, h * 0.14);
    for (var i = 0; i < 8; i++) {
      crimp.relativeLineTo(w * 0.115, i.isEven ? -h * 0.08 : h * 0.08);
    }
    if (ghost) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = C.gold;
      if (fill < 1) {
        // A part-packet: faint outline, gold up to the level.
        stroke.color = C.gold.withValues(alpha: 0.45);
        canvas.save();
        canvas.clipRRect(body);
        canvas.drawRect(Rect.fromLTRB(0, body.bottom - body.height * fill.clamp(0, 1), w, h), Paint()..color = C.gold.withValues(alpha: 0.3));
        canvas.restore();
        _dashed(canvas, Path()..addRRect(body), stroke);
        _dashed(canvas, crimp, stroke);
        return;
      }
      _dashed(canvas, Path()..addRRect(body), stroke);
      _dashed(canvas, crimp, stroke);
      _label(canvas, size, C.gold);
      return;
    }
    if (fill >= 1) {
      canvas.drawPath(crimp, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFE7E1F2));
      canvas.drawRRect(body, Paint()..color = C.crystalTop);
      canvas.drawRect(Rect.fromLTWH(0, h * 0.5, w, h * 0.26), Paint()..color = C.crystalLeft);
      _label(canvas, size, C.night);
      return;
    }
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFF4A4366);
    canvas.drawPath(crimp, outline);
    canvas.save();
    canvas.clipRRect(body);
    final top = body.bottom - (body.height * fill.clamp(0, 1));
    canvas.drawRect(Rect.fromLTRB(0, top, w, h), Paint()..color = C.crystalLeft);
    canvas.restore();
    canvas.drawRRect(body, outline);
  }

  void _label(Canvas canvas, Size size, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: '1 kg', style: T.body(size.width * 0.2, color: color, weight: FontWeight.w700, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.63 - tp.height / 2));
  }

  void _dashed(Canvas canvas, Path path, Paint paint) {
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, min(d + 4, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(PacketPainter o) => o.fill != fill || o.ghost != ghost;
}

/// A row of packets for [grams]: full ones, then a partial one.
class PacketRow extends StatelessWidget {
  const PacketRow({super.key, required this.grams, this.ghost = false, this.max = 5});
  final int grams;
  final bool ghost;
  final int max;

  @override
  Widget build(BuildContext context) {
    final full = grams ~/ 1000;
    final rest = (grams % 1000) / 1000;
    final shown = full.clamp(0, max);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < shown; i++) _packet(1),
        if (full <= max && (rest > 0.04 || full == 0)) _packet(rest),
        if (full > max) Padding(padding: const EdgeInsets.only(left: 4), child: Text('+${full - max}', style: T.body(14, color: ghost ? C.gold : C.soft, weight: FontWeight.w600))),
      ],
    );
  }

  Widget _packet(double fill) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: SizedBox(width: 34, height: 46, child: CustomPaint(painter: PacketPainter(fill: fill, ghost: ghost))),
      );
}

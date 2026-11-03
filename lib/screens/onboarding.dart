import 'dart:math';

import 'package:flutter/material.dart';

import '../reminders.dart';
import '../sky.dart';
import '../state.dart';
import '../theme.dart';
import 'sugar_tab.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.state});
  final AppState state;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool _askBaseline = false;

  Future<void> _start() async {
    await Reminders.requestPermission();
    widget.state.finishOnboarding();
    Reminders.reschedule(widget.state);
  }

  /// One question, so "sugar skipped" can mean something later.
  Widget _baseline() {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const CrystalIcon(size: 56),
              const SizedBox(height: 24),
              Text('Before today, how much added sugar on a usual day?', style: T.display(32, height: 1.08)),
              const SizedBox(height: 12),
              Text(
                'Each clean night, that\'s sugar you skipped. We\'ll add it up for you. A rough guess is fine: one teaspoon is 4 g, a can of soda about 35 g.',
                style: T.body(16),
              ),
              const SizedBox(height: 24),
              BaselineChips(
                onPick: (g) {
                  widget.state.setBaseline(g);
                  _start();
                },
              ),
              const Spacer(),
              Center(
                child: TextButton(
                  onPressed: () {
                    widget.state.setBaseline(null);
                    _start();
                  },
                  child: Text('Not sure, ask me later', style: T.body(15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_askBaseline) return _baseline();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  label: 'A sugar crystal breaking apart, its pieces rising and turning into stars',
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (_, _) => CustomPaint(size: Size.infinite, painter: _RisingPainter(_c.value)),
                  ),
                ),
              ),
              Text('Dissolve the sugar.\nLight up your sky.', style: T.display(36, height: 1.05)),
              const SizedBox(height: 16),
              Text(
                'Every day without added sugar, one sugar crystal turns into a star. String enough together and you get a constellation.',
                style: T.body(17, height: 1.5),
              ),
              const SizedBox(height: 12),
              Text('Whole fruit, plain milk and grains are fine. Only added sugar counts.', style: T.body(14, color: C.muted)),
              const SizedBox(height: 32),
              Pill(label: 'Start tonight', onPressed: () => setState(() => _askBaseline = true)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A crystal at the bottom shedding shards that drift up and become stars.
class _RisingPainter extends CustomPainter {
  _RisingPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Offset(size.width / 2, size.height * 0.72);
    canvas.drawCircle(base, 70, Paint()..color = C.crystalLeft.withValues(alpha: 0.06));
    paintCrystal(canvas, base, 88);

    final stars = [
      Offset(0.2, 0.28),
      Offset(0.36, 0.16),
      Offset(0.52, 0.1),
      Offset(0.66, 0.22),
      Offset(0.82, 0.12),
    ].map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();
    final line = Path()..moveTo(stars[0].dx, stars[0].dy);
    for (final s in stars.skip(1)) {
      line.lineTo(s.dx, s.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = C.gold.withValues(alpha: 0.35),
    );

    for (var i = 0; i < stars.length; i++) {
      final pulse = 0.5 + 0.5 * sin((t + i / 5) * 2 * pi);
      canvas.drawCircle(stars[i], 7 + 4 * pulse, Paint()..color = C.gold.withValues(alpha: 0.08));
      canvas.drawCircle(stars[i], i == 3 ? 3.4 : 2.4, Paint()..color = C.gold);
    }

    // Shards rise from the crystal toward the stars, turning gold as they go.
    for (var i = 0; i < 7; i++) {
      final k = (t + i / 7) % 1.0;
      final target = stars[i % stars.length];
      final start = base + Offset((i - 3) * 6.0, -30);
      final p = Offset.lerp(start, target, Curves.easeInOut.transform(k))! + Offset(sin(k * 6 + i) * 10, 0);
      final s = 4.5 * (1 - k) + 1;
      final col = Color.lerp(C.crystalTop, C.gold, k)!.withValues(alpha: (1 - k) * 0.9);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(k * 5 + i);
      canvas.drawPath(Path()..addPolygon([Offset(-s, -s * 0.6), Offset(s, -s * 0.2), Offset(-s * 0.2, s)], true), Paint()..color = col);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_RisingPainter o) => o.t != t;
}

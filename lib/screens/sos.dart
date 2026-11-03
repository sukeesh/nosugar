import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sky.dart';
import '../theme.dart';

/// Ninety seconds of paced breathing while a sugar crystal dissolves.
/// Pops `true` if the craving passed.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  static const total = Duration(seconds: 90);
  static const inhale = 4.0, exhale = 6.0;

  late final AnimationController _run = AnimationController(vsync: this, duration: total)..forward();
  bool _wasInhaling = true;

  @override
  void initState() {
    super.initState();
    _run.addListener(() {
      final inhaling = _phase.$1;
      if (inhaling != _wasInhaling) {
        _wasInhaling = inhaling;
        HapticFeedback.lightImpact();
      }
    });
    _run.addStatusListener((s) {
      if (s == AnimationStatus.completed) HapticFeedback.mediumImpact();
    });
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  double get _elapsed => _run.value * total.inSeconds;

  /// (inhaling?, progress within the phase 0..1, seconds left in the phase)
  (bool, double, int) get _phase {
    final t = _elapsed % (inhale + exhale);
    if (t < inhale) return (true, t / inhale, (inhale - t).ceil());
    return (false, (t - inhale) / exhale, (inhale + exhale - t).ceil());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.sosBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 24, 16),
          child: AnimatedBuilder(
            animation: _run,
            builder: (context, _) {
              final done = _run.isCompleted;
              final left = (total.inSeconds - _elapsed).ceil();
              final (inhaling, p, count) = _phase;
              final breath = inhaling ? Curves.easeInOut.transform(p) : 1 - Curves.easeInOut.transform(p);
              return Column(
                children: [
                  Row(
                    children: [
                      CircleIconButton(icon: Icons.close_rounded, tooltip: 'Close', border: C.sosLine, onPressed: () => Navigator.of(context).pop(false)),
                      const Spacer(),
                      Text(done ? '' : '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}',
                          style: T.body(15, color: C.sos, weight: FontWeight.w600).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(done ? 'Still here.\nStill strong.' : 'Watch it dissolve.', textAlign: TextAlign.center, style: T.display(34, height: 1.08)),
                  const SizedBox(height: 10),
                  Text(
                    done ? 'Most cravings fade if you wait them out.\nYou just did.' : 'Breathe with the circle. The craving\nshrinks with the crystal.',
                    textAlign: TextAlign.center,
                    style: T.body(16, color: C.sosSoft),
                  ),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: CustomPaint(painter: _DissolvePainter(progress: _run.value, breath: breath, time: _elapsed)),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 34,
                    child: done
                        ? null
                        : Text('${inhaling ? 'Breathe in' : 'Breathe out'} · $count', style: T.display(24, weight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 24),
                  Pill(
                    label: 'It passed',
                    background: C.sos,
                    foreground: const Color(0xFF06121F),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                  const SizedBox(height: 12),
                  Text('Each craving you outlast adds a shooting star.', style: T.body(14, color: C.sosSoft)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DissolvePainter extends CustomPainter {
  _DissolvePainter({required this.progress, required this.breath, required this.time});
  final double progress, breath, time;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 4;

    canvas.drawCircle(c, r * (0.62 + 0.3 * breath), Paint()..color = C.sos.withValues(alpha: 0.06 + 0.06 * breath));
    canvas.drawCircle(c, r * (0.45 + 0.25 * breath), Paint()..color = C.sos.withValues(alpha: 0.08));
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, ring..color = const Color(0xFF1D3550));
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi / 2, 2 * pi * progress, false, ring..color = C.sos);

    // The crystal shrinks and melts; grains drift up from it.
    final left = 1 - progress;
    final crystalSize = r * 0.55 * (0.15 + 0.85 * left);
    paintCrystal(canvas, c + Offset(0, r * 0.12), crystalSize, opacity: 0.35 + 0.6 * left, melt: progress * 0.8);

    final rnd = Random(5);
    for (var i = 0; i < 26; i++) {
      final speed = 0.25 + rnd.nextDouble() * 0.35;
      final phase = rnd.nextDouble();
      final t = (time * speed / 4 + phase) % 1.0;
      if (i / 26 > 0.35 + progress) continue;
      final x = c.dx + (rnd.nextDouble() - 0.5) * crystalSize * 1.1 + sin((t + phase) * 6) * 6;
      final y = c.dy + r * 0.05 - t * r * 0.75;
      final s = 1.5 + rnd.nextDouble() * 2;
      canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: s, height: s), Paint()..color = C.crystalTop.withValues(alpha: (1 - t) * 0.8));
    }
  }

  @override
  bool shouldRepaint(_DissolvePainter o) => true;
}

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../crystal.dart';
import '../sky.dart';
import '../state.dart';
import '../theme.dart';

enum StreakCard { constellation, number, milestone }

const _monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthsLong = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// The biggest milestone the current constellation has reached, if any.
Milestone? reachedMilestone(AppState s) {
  Milestone? hit;
  for (final m in milestones) {
    if (m.night <= s.streak) hit = m;
  }
  return hit;
}

/// "Share your streak": a 9:16 card (fits Stories and Status) rendered to an
/// image. Only clean progress is shown, never slips or logged sugar.
class StreakShareScreen extends StatefulWidget {
  const StreakShareScreen({super.key, required this.state, this.initial = StreakCard.constellation});
  final AppState state;
  final StreakCard initial;

  @override
  State<StreakShareScreen> createState() => _StreakShareScreenState();
}

class _StreakShareScreenState extends State<StreakShareScreen> {
  final _key = GlobalKey();
  late StreakCard _card = widget.initial == StreakCard.milestone && reachedMilestone(widget.state) == null ? StreakCard.constellation : widget.initial;
  bool _busy = false;

  Future<File> _render() async {
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    // 270 × 480 logical → 1080 × 1920, the native Story size.
    final image = await boundary.toImage(pixelRatio: 4);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${(await getTemporaryDirectory()).path}/nosugar-streak-${widget.state.streak}.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    return file;
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final file = await _render();
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final milestone = reachedMilestone(s);
    return Scaffold(
      backgroundColor: const Color(0xFF070A16),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: const CloseButton(color: C.soft),
        title: Text(
          'Share your streak',
          style: T.body(16, color: C.text, weight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: FittedBox(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [BoxShadow(color: Color(0x8C000000), blurRadius: 60, offset: Offset(0, 24))],
                      ),
                      child: RepaintBoundary(
                        key: _key,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: SizedBox(
                            width: 270,
                            height: 480,
                            child: switch (_card) {
                              StreakCard.constellation => _ConstellationCard(state: s),
                              StreakCard.number => _NumberCard(state: s),
                              StreakCard.milestone => _MilestoneCard(state: s, milestone: milestone!),
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('9:16 · fits Stories and Status', style: T.body(12, color: C.muted)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _chip('Constellation', StreakCard.constellation),
                  _chip('Big number', StreakCard.number),
                  if (milestone != null) _chip('Milestone', StreakCard.milestone),
                ],
              ),
              const SizedBox(height: 20),
              Pill(
                label: _busy ? 'Preparing…' : 'Share',
                icon: const Icon(Icons.ios_share_rounded, size: 18, color: C.ink),
                onPressed: _busy ? null : _share,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, StreakCard card) {
    final on = _card == card;
    return Semantics(
      selected: on,
      button: true,
      child: TextButton(
        onPressed: () => setState(() => _card = card),
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          backgroundColor: on ? C.moon : Colors.transparent,
          shape: StadiumBorder(side: BorderSide(color: on ? C.moon : C.dim)),
        ),
        child: Text(
          label,
          style: T.body(14, color: on ? C.night : C.soft, weight: on ? FontWeight.w600 : FontWeight.w400, height: 1),
        ),
      ),
    );
  }
}

Widget _wordmark(double size) => Text.rich(
  TextSpan(
    children: [
      TextSpan(text: 'nosugar', style: T.display(size)),
      TextSpan(
        text: '.',
        style: T.display(size, color: C.gold),
      ),
    ],
  ),
);

Widget _kicker(String text, {Color color = C.muted}) => Text(
  text.toUpperCase(),
  style: T.body(11, color: color, weight: FontWeight.w600, height: 1).copyWith(letterSpacing: 1.3),
);

String _nightsLine(AppState s) {
  final moonNights = s.current.length - s.current.stars;
  return moonNights == 0 ? 'nights without\nadded sugar' : 'night streak,\n$moonNights forgiven by a moon';
}

String? _skippedLine(AppState s) {
  final b = s.baselineGrams;
  if (b == null || s.current.stars == 0) return null;
  return '≈ ${formatGrams(b * s.current.stars)} of sugar skipped';
}

class _ConstellationCard extends StatelessWidget {
  const _ConstellationCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final start = s.current.start;
    final skipped = _skippedLine(s);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(center: Alignment(0, -0.45), radius: 1.1, colors: [Color(0xFF18204A), C.night, Color(0xFF070A16)], stops: [0, 0.6, 1]),
      ),
      child: CustomPaint(
        painter: _DustPainter(seed: 7),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kicker('My sugar-free streak'),
              const SizedBox(height: 18),
              SizedBox(
                height: 160,
                width: double.infinity,
                child: CustomPaint(
                  painter: SkyPainter(constellation: s.current, background: false, starBase: 2.2, padding: const EdgeInsets.all(10), maxUnit: 34),
                ),
              ),
              const SizedBox(height: 18),
              Text('${s.streak}', style: T.display(76, color: C.gold, height: 0.9)),
              const SizedBox(height: 6),
              Text(_nightsLine(s), style: T.display(24, height: 1.1)),
              const SizedBox(height: 12),
              Text('Since ${start.day} ${_monthsShort[start.month - 1]} · every star is a night', style: T.body(13, height: 1.2)),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(skipped ?? '', style: T.body(12, color: C.muted, height: 1.2)),
                  ),
                  _wordmark(16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberCard extends StatelessWidget {
  const _NumberCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final next = s.nextMilestone;
    final digits = '${s.streak}'.length;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0E1430), C.night]),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _kicker('Sugar-free')),
                if (s.moons > 0) ...[
                  for (var i = 0; i < s.moons; i++) const Icon(Icons.nightlight_round, size: 12, color: C.moon),
                  const SizedBox(width: 4),
                  Text('${s.moons} ${s.moons == 1 ? 'moon' : 'moons'} saved', style: T.body(12, color: C.moon, height: 1)),
                ],
              ],
            ),
            const SizedBox(height: 18),
            Text('${s.streak}', style: T.display(digits >= 3 ? 112 : 150, color: C.gold, height: 0.85).copyWith(letterSpacing: -6)),
            const SizedBox(height: 8),
            Text(s.streak == 1 ? 'night, and counting' : 'nights in a row', style: T.display(26, height: 1.1)),
            const SizedBox(height: 22),
            _MonthOfStars(state: s),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(next == null ? 'Whole sky lit' : 'Next: ${next.night} · ${next.name}', style: T.body(12, color: C.muted, height: 1.2)),
                ),
                _wordmark(16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The month of the latest night, with a star on each night of this streak.
class _MonthOfStars extends StatelessWidget {
  const _MonthOfStars({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final c = state.current;
    final nights = <DateTime, Night>{for (var i = 0; i < c.length; i++) addDays(c.start, i): c.nights[i]};
    final latest = c.length == 0 ? state.today : addDays(c.start, c.length - 1);
    final first = DateTime(latest.year, latest.month);
    final days = DateTime(latest.year, latest.month + 1, 0).day;
    final lead = first.weekday - 1; // Monday first
    Widget cell(Widget child) => SizedBox(height: 22, child: Center(child: child));
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
      decoration: BoxDecoration(
        color: C.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.line),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(_monthsLong[latest.month - 1], style: T.body(11, color: C.muted, height: 1)),
                ),
                Text('1 star = 1 clean night', style: T.body(11, color: C.muted, height: 1)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 26 / 22,
            padding: EdgeInsets.zero,
            children: [
              for (final d in 'MTWTFSS'.split('')) cell(Text(d, style: T.body(9, color: C.muted, height: 1))),
              for (var i = 0; i < lead; i++) const SizedBox(),
              for (var d = 1; d <= days; d++)
                cell(switch (nights[DateTime(latest.year, latest.month, d)]) {
                  Night.star => Icon(Icons.star_rounded, size: d == latest.day ? 18 : 15, color: d == latest.day ? const Color(0xFFFFF3D6) : C.gold),
                  Night.moon => const Icon(Icons.nightlight_round, size: 12, color: C.moon),
                  null => Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(color: C.dim, shape: BoxShape.circle),
                  ),
                }),
            ],
          ),
        ],
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({required this.state, required this.milestone});
  final AppState state;
  final Milestone milestone;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final skipped = s.baselineGrams == null ? null : s.baselineGrams! * min<int>(s.current.stars, milestone.night);
    final cravings = s.current.cravings;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.32),
          radius: 1.0,
          colors: [Color(0xFF3A2E12), Color(0xFF141022), Color(0xFF070A16)],
          stops: [0, 0.55, 1],
        ),
      ),
      child: CustomPaint(
        painter: _DustPainter(seed: 3, count: 20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          child: Column(
            children: [
              _kicker('Milestone unlocked', color: C.gold),
              const SizedBox(height: 12),
              SizedBox(width: 168, height: 168, child: CustomPaint(painter: _RingPainter(milestone.night))),
              const SizedBox(height: 8),
              Text(milestone.name, textAlign: TextAlign.center, style: T.display(30, height: 1.05)),
              const SizedBox(height: 8),
              Text('${milestone.night} nights without added sugar.\n${milestone.note}', textAlign: TextAlign.center, style: T.body(13, height: 1.4)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  if (skipped != null && skipped > 0) _tag('≈ ${formatGrams(skipped)} skipped', C.gold),
                  if (cravings > 0) _tag('$cravings ${cravings == 1 ? 'craving' : 'cravings'} outlasted', C.moon),
                ],
              ),
              const Spacer(),
              Text('Try one night with me', style: T.body(12, color: C.muted, height: 1)),
              const SizedBox(height: 6),
              _wordmark(18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
    child: Text(text, style: T.body(12, color: color, height: 1.2)),
  );
}

/// One star per night of the milestone, in a ring around the number.
class _RingPainter extends CustomPainter {
  _RingPainter(this.nights);
  final int nights;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 10;
    canvas.drawCircle(c, r * 0.76, Paint()..color = C.gold.withValues(alpha: 0.08));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = C.gold.withValues(alpha: 0.25),
    );
    final dot = (2 * pi * r / nights * 0.22).clamp(1.2, 4.0);
    for (var i = 0; i < nights; i++) {
      final a = -pi / 2 + i * 2 * pi / nights;
      final big = nights <= 30 && i % 5 == 4;
      canvas.drawCircle(c + Offset(cos(a), sin(a)) * r, big ? dot * 1.4 : dot, Paint()..color = C.gold);
    }
    final tp = TextPainter(
      text: TextSpan(
        text: '$nights',
        style: T.display(nights >= 100 ? 46 : 56, color: const Color(0xFFFFF3D6)).copyWith(letterSpacing: -3),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.nights != nights;
}

/// A faint scatter of background stars.
class _DustPainter extends CustomPainter {
  _DustPainter({required this.seed, this.count = 26});
  final int seed;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(seed);
    for (var i = 0; i < count; i++) {
      final p = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      canvas.drawCircle(p, 0.6 + rnd.nextDouble() * 0.6, Paint()..color = C.text.withValues(alpha: 0.2 + rnd.nextDouble() * 0.35));
    }
  }

  @override
  bool shouldRepaint(_DustPainter o) => false;
}

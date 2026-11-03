import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../crystal.dart';
import '../state.dart';
import '../theme.dart';
import 'slip.dart';

/// Right after a log: the newest crystal grows in, with sparkles. Then, if the
/// night still needs deciding, the moon / new-constellation choice.
class GrowScreen extends StatefulWidget {
  const GrowScreen({super.key, required this.state, required this.day, required this.added, required this.before, this.tag});
  final AppState state;
  final DateTime day;
  final int added;
  final int before;
  final String? tag;

  @override
  State<GrowScreen> createState() => _GrowScreenState();
}

class _GrowScreenState extends State<GrowScreen> with TickerProviderStateMixin {
  late final AnimationController _grow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();
  late final AnimationController _sparkle = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), HapticFeedback.mediumImpact);
  }

  @override
  void dispose() {
    _grow.dispose();
    _sparkle.dispose();
    super.dispose();
  }

  bool get _needsDecision {
    final s = widget.state;
    // Only when this is the night the check-in is waiting on; logging today
    // while older nights are unanswered mustn't skip past them.
    return s.pendingDay == widget.day && (s.lastDay == null || s.lastDay!.isBefore(widget.day));
  }

  void _continue() {
    if (_needsDecision) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SlipScreen(state: widget.state, day: widget.day, initialTag: widget.tag)));
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final after = widget.before + widget.added;
    final newPoint = crystalCount(after) > crystalCount(widget.before);
    final levelUp = levelFor(after) != levelFor(widget.before);
    final next = nextLevel(after);
    final logs = s.honestLogs();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(color: const Color(0xFF1C1A2E), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF4A4366))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.auto_awesome, size: 14, color: C.gold),
                  const SizedBox(width: 8),
                  Text('+1 honesty shard · $logs honest ${logs == 1 ? 'log' : 'logs'}', style: T.body(14, color: C.text, height: 1)),
                ]),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_grow, _sparkle]),
                  builder: (_, _) => Semantics(
                    label: 'Your sugar crystal cluster${newPoint ? ', with a new crystal growing' : ''}',
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: ClusterPainter(
                        grams: after,
                        grow: newPoint ? _grow.value : 1,
                        highlightNewest: newPoint,
                        sparkle: _sparkle.value,
                      ),
                    ),
                  ),
                ),
              ),
              Text('+${widget.added} g', style: T.display(44)),
              const SizedBox(height: 8),
              Text(
                levelUp
                    ? 'It\'s a ${levelFor(after).name} now.'
                    : newPoint
                        ? '${_cap(teaspoons(widget.added))}. Your crystal grew a new point.'
                        : '${_cap(teaspoons(widget.added))}. Your crystal got a little heavier.',
                textAlign: TextAlign.center,
                style: T.body(16),
              ),
              const SizedBox(height: 20),
              if (next != null)
                Row(
                  children: [
                    Text(formatGrams(after), style: T.body(13, color: C.muted)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: ((after - levelFor(after).grams) / (next.grams - levelFor(after).grams)).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: C.line,
                          color: C.crystalLeft,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${next.name} at ${formatGrams(next.grams)}', style: T.body(13, color: C.muted)),
                  ],
                ),
              const SizedBox(height: 24),
              Pill(label: _needsDecision ? 'Continue' : 'Done', outlined: true, onPressed: _continue),
            ],
          ),
        ),
      ),
    );
  }

  String _cap(String s) => s[0].toUpperCase() + s.substring(1);
}

import 'package:flutter/material.dart';

import '../crystal.dart';
import '../state.dart';
import '../theme.dart';
import 'share_card.dart';
import 'sugar_log.dart';

/// "Your sugar": what you ate as a crystal cluster and kitchen packets, and in
/// gold, the sugar you skipped on clean nights.
class SugarView extends StatefulWidget {
  const SugarView({super.key, required this.state});
  final AppState state;

  @override
  State<SugarView> createState() => _SugarViewState();
}

class _SugarViewState extends State<SugarView> {
  bool _lifetime = false;

  AppState get s => widget.state;
  int? get _year => _lifetime ? null : s.today.year;

  void _log() {
    Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => SugarLogScreen(state: s, day: s.today)));
  }

  @override
  Widget build(BuildContext context) {
    final eaten = s.gramsEaten(year: _year);
    final skipped = s.gramsSkipped(year: _year);
    final logs = s.honestLogs(year: _year);
    final weighs = weighsLike(eaten);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text('${s.today.year}')),
              const ButtonSegment(value: true, label: Text('Lifetime')),
            ],
            selected: {_lifetime},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => _lifetime = v.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: C.crystalLeft,
              selectedForegroundColor: C.night,
              foregroundColor: C.soft,
              side: const BorderSide(color: C.line),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        Semantics(
          label: 'Your sugar crystal cluster, ${formatGrams(eaten)}',
          child: Cluster(grams: eaten, height: 210),
        ),
        const SizedBox(height: 4),
        Text(eaten == 0 ? 'Nothing logged' : formatGrams(eaten), textAlign: TextAlign.center, style: T.display(52)),
        const SizedBox(height: 6),
        Text(
          eaten == 0
              ? 'When you do have sugar, log it here.\nHonest logs grow this crystal.'
              : '${_lifetime ? 'eaten in total' : 'eaten this year'} · ${teaspoons(eaten)}',
          textAlign: TextAlign.center,
          style: T.body(15),
        ),
        if (weighs != null) Text(weighs[0].toUpperCase() + weighs.substring(1), textAlign: TextAlign.center, style: T.body(14, color: C.muted)),
        const SizedBox(height: 16),
        if (eaten > 0)
          _Card(
            child: Row(children: [
              PacketRow(grams: eaten),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(packets(eaten), style: T.body(16, color: C.text, weight: FontWeight.w600)),
                  Text('of the 1 kg kind in your kitchen', style: T.body(13, color: C.muted)),
                ]),
              ),
            ]),
          ),
        const SizedBox(height: 10),
        if (skipped == null) _BaselinePrompt(state: s) else _skippedCard(skipped),
        const SizedBox(height: 12),
        Text('$logs honest ${logs == 1 ? 'log' : 'logs'} · ${levelFor(eaten).name}', textAlign: TextAlign.center, style: T.body(13, color: C.muted)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Pill(label: 'Log sugar', outlined: true, height: 52, onPressed: _log)),
          const SizedBox(width: 10),
          Expanded(
            child: Pill(
              label: 'Share',
              height: 52,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => ShareCardScreen(state: s))),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _skippedCard(int skipped) {
    final weighs = weighsLike(skipped);
    return _Card(
      gold: true,
      child: Row(children: [
        if (skipped >= 50) PacketRow(grams: skipped, ghost: true),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${formatGrams(skipped)} skipped', style: T.body(16, color: C.gold, weight: FontWeight.w600)),
            Text(
              skipped == 0 ? 'Light a star and this starts to grow.' : weighs == null ? 'On your clean nights' : '${weighs[0].toUpperCase()}${weighs.substring(1)}, never eaten',
              style: T.body(13, color: C.soft),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.gold = false});
  final Widget child;
  final bool gold;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: gold ? const Color(0xFF1A1710) : C.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: gold ? const Color(0xFF4A3D1C) : C.line),
        ),
        child: child,
      );
}

/// Asked once: without the old habit we can't say how much sugar was skipped.
class _BaselinePrompt extends StatelessWidget {
  const _BaselinePrompt({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return _Card(
      gold: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('See the sugar you skipped', style: T.body(16, color: C.gold, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Before nosugar, how much added sugar did you have on a usual day?', style: T.body(13, color: C.soft)),
          const SizedBox(height: 10),
          BaselineChips(onPick: state.setBaseline),
        ],
      ),
    );
  }
}

/// Shared with onboarding.
class BaselineChips extends StatelessWidget {
  const BaselineChips({super.key, required this.onPick});
  final void Function(int? grams) onPick;

  static const options = [
    ('A little', '≈ 10 g', 10),
    ('Some', '≈ 25 g', 25),
    ('A lot', '≈ 50 g', 50),
    ('Loads', '≈ 80 g', 80),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          ActionChip(
            onPressed: () => onPick(o.$3),
            backgroundColor: C.night,
            side: const BorderSide(color: C.dim),
            shape: const StadiumBorder(),
            label: Text('${o.$1} ${o.$2}', style: T.body(14, color: C.text, height: 1.2)),
          ),
      ],
    );
  }
}

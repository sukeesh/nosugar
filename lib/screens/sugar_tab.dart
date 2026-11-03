import 'package:flutter/material.dart';

import '../state.dart';
import '../sugar.dart';
import '../sugar_names.dart';
import '../theme.dart';
import 'pour.dart';
import 'receipt.dart';
import 'scan.dart';

enum _Period { month, year, all }

/// Everything about sugar: what was eaten as a pile of grains, the pile the
/// old habit would have made, the label scanner, a receipt and the names.
class SugarTab extends StatefulWidget {
  const SugarTab({super.key, required this.state});
  final AppState state;

  @override
  State<SugarTab> createState() => _SugarTabState();
}

class _SugarTabState extends State<SugarTab> with SingleTickerProviderStateMixin {
  _Period _period = _Period.year;
  late final AnimationController _settle = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();

  // Screenshot helper: SCREEN=sugar2 opens scrolled down.
  final _scroll = ScrollController(initialScrollOffset: AppState.demo && const String.fromEnvironment('SCREEN') == 'sugar2' ? 640 : 0);

  AppState get s => widget.state;
  int? get _year => _period == _Period.all ? null : s.today.year;
  int? get _month => _period == _Period.month ? s.today.month : null;

  @override
  void dispose() {
    _settle.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _setPeriod(_Period p) {
    setState(() => _period = p);
    _settle.forward(from: 0);
  }

  void _pour() => Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PourScreen(state: s, day: s.today),
    ),
  );
  void _scan() => Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const ScanScreen()));
  void _receipt() => Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ReceiptScreen(state: s, year: s.today.year, month: s.today.month),
    ),
  );

  String get _when => switch (_period) {
    _Period.month => 'in ${monthNames[s.today.month - 1]}',
    _Period.year => 'this year',
    _Period.all => 'since you started',
  };

  String get _ghostLabel => switch (_period) {
    _Period.month => 'a usual ${monthNames[s.today.month - 1]}, before',
    _Period.year => 'the ${s.today.year} you would have eaten',
    _Period.all => 'what you would have eaten',
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final eaten = s.gramsEaten(year: _year, month: _month);
        final skipped = s.gramsSkipped(year: _year, month: _month);
        final ghost = skipped == null ? null : eaten + skipped;
        final still = MediaQuery.disableAnimationsOf(context);
        return SafeArea(
          bottom: false,
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Row(
                children: [
                  Expanded(child: Text('Sugar', style: T.display(36))),
                  _PeriodSwitch(value: _period, year: s.today.year, onChanged: _setPeriod),
                ],
              ),
              const SizedBox(height: 12),
              Semantics(
                label: '${formatGrams(eaten)} of sugar $_when${ghost == null ? '' : ', out of about ${formatGrams(ghost)} at your old habit'}',
                child: SizedBox(
                  height: 290,
                  child: AnimatedBuilder(
                    animation: _settle,
                    builder: (_, _) => CustomPaint(
                      size: Size.infinite,
                      painter: GrainPilePainter(
                        grams: eaten,
                        ghostGrams: ghost,
                        ghostLabel: ghost == null || ghost == 0 ? null : '${formatGrams(ghost)} · $_ghostLabel',
                        reference: 2000,
                        progress: still ? 1 : Curves.easeOutCubic.transform(_settle.value),
                        floorStar: eaten == 0,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(formatGrams(eaten), textAlign: TextAlign.center, style: T.display(56, height: 1)),
              const SizedBox(height: 6),
              Text(
                eaten == 0 ? '${_cap(_when)}. Not a single grain.' : 'is all you had $_when · ${teaspoons(eaten)}',
                textAlign: TextAlign.center,
                style: T.body(15),
              ),
              if (skipped != null && skipped > 0) ...[
                const SizedBox(height: 4),
                Text(
                  eaten == 0 ? 'All ${formatGrams(skipped)} stayed off your plate.' : '${formatGrams(skipped)} never made it to your plate',
                  textAlign: TextAlign.center,
                  style: T.body(15, color: C.gold, weight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 20),
              if (skipped == null) ...[_BaselinePrompt(state: s), const SizedBox(height: 12)],
              Pill(
                label: 'I had some sugar',
                outlined: true,
                height: 56,
                icon: const Icon(Icons.add_rounded, size: 20, color: C.text),
                onPressed: _pour,
              ),
              const SizedBox(height: 24),
              _ScanCard(onTap: _scan),
              const SizedBox(height: 28),
              _ReceiptCard(state: s, onShare: _receipt),
              if (s.logsIn(year: _year, month: _month).isNotEmpty) ...[const SizedBox(height: 28), _SugarMap(state: s, year: _year, month: _month)],
              const SizedBox(height: 28),
              const _Names(),
            ],
          ),
        );
      },
    );
  }

  static String _cap(String t) => t[0].toUpperCase() + t.substring(1);
}

class _PeriodSwitch extends StatelessWidget {
  const _PeriodSwitch({required this.value, required this.year, required this.onChanged});
  final _Period value;
  final int year;
  final ValueChanged<_Period> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, _Period p) {
      final on = value == p;
      return Semantics(
        selected: on,
        button: true,
        child: GestureDetector(
          onTap: () => onChanged(p),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: on ? C.text : Colors.transparent, borderRadius: BorderRadius.circular(16)),
            child: Text(
              label,
              style: T.body(13, color: on ? C.night : C.muted, weight: on ? FontWeight.w600 : FontWeight.w400, height: 1),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: C.line),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [seg('Month', _Period.month), seg('$year', _Period.year), seg('All', _Period.all)]),
    );
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1C2444), C.surface]),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF2C3458)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.document_scanner_outlined, color: C.ink, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Check a label',
                      style: T.body(17, color: C.text, weight: FontWeight.w600, height: 1.2),
                    ),
                    const SizedBox(height: 2),
                    Text('Point at ingredients. We find the hidden sugar.', style: T.body(13, color: C.muted, height: 1.3)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: C.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.state, required this.onShare});
  final AppState state;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final logs = s.logsIn(year: s.today.year, month: s.today.month)..sort((a, b) => b.day.compareTo(a.day));
    final mono = T.body(13, color: C.text, height: 1.2).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('${monthNames[s.today.month - 1]} receipt', style: T.display(22))),
            TextButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.ios_share_rounded, size: 16, color: C.soft),
              label: Text('Share', style: T.body(14, color: C.soft)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: C.line),
          ),
          child: Column(
            children: [
              if (logs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('Nothing yet this month. Not a single grain.', style: T.body(14, color: C.muted)),
                ),
              for (final l in logs.take(4))
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: C.line)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text('${l.day.day} ${monthNames[l.day.month - 1].substring(0, 3)}', style: mono.copyWith(color: C.muted)),
                      ),
                      Expanded(child: Text(l.label ?? s.sugarCategory(l).replaceFirst('Other', 'Sugar'), style: mono)),
                      Text('${l.grams} g', style: mono),
                    ],
                  ),
                ),
              if (logs.length > 4)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('+${logs.length - 4} more', style: mono.copyWith(color: C.muted)),
                  ),
                ),
              if (logs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Total', style: mono.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      Text(
                        formatGrams(s.gramsEaten(year: s.today.year, month: s.today.month)),
                        style: mono.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Where the sugar came from, by slip tag.
class _SugarMap extends StatelessWidget {
  const _SugarMap({required this.state, this.year, this.month});
  final AppState state;
  final int? year;
  final int? month;

  static const _colors = [Color(0xFFE6E1F2), Color(0xFFBDB4D6), Color(0xFF8F86B0), Color(0xFF6A6290), Color(0xFF5A6488)];

  @override
  Widget build(BuildContext context) {
    final by = <String, int>{};
    for (final l in state.logsIn(year: year, month: month)) {
      final c = state.sugarCategory(l);
      by[c] = (by[c] ?? 0) + l.grams;
    }
    final total = by.values.fold(0, (a, b) => a + b);
    final parts = by.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    String name(String c) => switch (c) {
      'Sweet drink' => 'Drinks',
      'Dessert' => 'Desserts',
      'Snack' => 'Snacks',
      _ => c,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your sugar map', style: T.display(22)),
        const SizedBox(height: 4),
        Text('Where it came from', style: T.body(14, color: C.muted)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            height: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < parts.length; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(
                    flex: parts[i].value,
                    child: ColoredBox(color: _colors[i % _colors.length]),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            for (var i = 0; i < parts.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: _colors[i % _colors.length], shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text('${name(parts[i].key)} · ${(parts[i].value * 100 / total).round()}%', style: T.body(13, height: 1.2)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _Names extends StatelessWidget {
  const _Names();

  static const _first = ['dextrose', 'maltodextrin', 'jaggery', 'rice syrup', 'invert sugar', 'fruit juice concentrate', 'barley malt'];

  @override
  Widget build(BuildContext context) {
    final shown = _first.where(sugarNames.contains).toList();
    final rest = sugarNames.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sugar wears ${sugarNames.length} names', style: T.display(22)),
        const SizedBox(height: 4),
        Text('Learn them and labels stop fooling you.', style: T.body(14, color: C.muted)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final n in shown) _NameChip(n),
            ActionChip(
              onPressed: () => _all(context),
              backgroundColor: C.surface,
              side: const BorderSide(color: C.dim),
              shape: const StadiumBorder(),
              label: Text('+$rest more', style: T.body(13, color: C.text, height: 1.2)),
            ),
          ],
        ),
      ],
    );
  }

  void _all(BuildContext context) {
    final names = [...sugarNames]..sort();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Text('${names.length} names for sugar', style: T.display(26)),
            const SizedBox(height: 6),
            Text('If one of these is in the ingredients, it has added sugar. Check a label finds them for you.', style: T.body(14, color: C.muted)),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [for (final n in names) _NameChip(n)]),
          ],
        ),
      ),
    );
  }
}

class _NameChip extends StatelessWidget {
  const _NameChip(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: ShapeDecoration(
        shape: const StadiumBorder(side: BorderSide(color: C.dim)),
      ),
      child: Text(name[0].toUpperCase() + name.substring(1), style: T.body(13, color: C.soft, height: 1.2)),
    );
  }
}

/// Asked once: without the old habit there's no "would have eaten" pile.
class _BaselinePrompt extends StatelessWidget {
  const _BaselinePrompt({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1710),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4A3D1C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'See the sugar you skipped',
            style: T.body(16, color: C.gold, weight: FontWeight.w600),
          ),
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

  static const options = [('A little', '≈ 10 g', 10), ('Some', '≈ 25 g', 25), ('A lot', '≈ 50 g', 50), ('Loads', '≈ 80 g', 80)];

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

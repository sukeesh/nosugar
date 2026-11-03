import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../crystal.dart';
import '../sky.dart';
import '../state.dart';
import '../theme.dart';
import 'grow.dart';
import 'slip.dart';

class _Pick {
  const _Pick(this.name, this.grams, this.tag);
  final String name;
  final int grams;
  final String tag;
}

// Rough, deliberately round estimates; the stepper is there to correct them.
const _picks = [
  _Pick('Chai, 2 tsp', 8, 'Sweet drink'),
  _Pick('Can of soda', 35, 'Sweet drink'),
  _Pick('Chocolate bar', 25, 'Snack'),
  _Pick('Dessert', 30, 'Dessert'),
];

/// "How much sugar?" Logging is the honest move, so it earns a shard whatever
/// the amount. After this: the cluster grows, then the usual slip choice.
class SugarLogScreen extends StatefulWidget {
  const SugarLogScreen({super.key, required this.state, required this.day});
  final AppState state;
  final DateTime day;

  @override
  State<SugarLogScreen> createState() => _SugarLogScreenState();
}

class _SugarLogScreenState extends State<SugarLogScreen> {
  int _grams = 8;
  _Pick? _pick;

  void _step(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _grams = (_grams + delta).clamp(4, 400);
      _pick = null;
    });
  }

  void _choose(_Pick p) {
    HapticFeedback.selectionClick();
    setState(() {
      _pick = p;
      _grams = p.grams;
    });
  }

  void _add() {
    final s = widget.state;
    final before = s.gramsEaten(year: s.today.year);
    s.logSugar(widget.day, _grams, label: _pick?.name);
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, _, _) => GrowScreen(state: s, day: widget.day, added: _grams, before: before, tag: _pick?.tag),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  void _skip() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SlipScreen(state: widget.state, day: widget.day)));
  }

  @override
  Widget build(BuildContext context) {
    final cubes = _grams / 4;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: const CloseButton(color: C.soft),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: const Color(0xFF1C1A2E), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              const Icon(Icons.auto_awesome, size: 13, color: C.gold),
              const SizedBox(width: 6),
              Text('Honest logs earn a shard', style: T.body(13, color: C.crystalLeft, height: 1)),
            ]),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('How much sugar?', style: T.display(34, height: 1.05)),
              const SizedBox(height: 8),
              Text('A guess is fine. Every gram becomes part of your crystal.', style: T.body(15, color: C.muted)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: C.line)),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'One teaspoon less',
                          onPressed: _grams > 4 ? () => _step(-4) : null,
                          icon: const Icon(Icons.remove_rounded, color: C.text),
                          style: IconButton.styleFrom(fixedSize: const Size(52, 52), shape: const CircleBorder(side: BorderSide(color: C.dim))),
                        ),
                        SizedBox(
                          width: 150,
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(text: '$_grams', style: T.display(72, height: 1)),
                              TextSpan(text: ' g', style: T.display(30, color: C.muted, height: 1)),
                            ]),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          tooltip: 'One teaspoon more',
                          onPressed: () => _step(4),
                          icon: const Icon(Icons.add_rounded, color: C.night),
                          style: IconButton.styleFrom(fixedSize: const Size(52, 52), backgroundColor: C.crystalLeft, shape: const CircleBorder()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < cubes.ceil().clamp(1, 6); i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: CrystalIcon(size: 22, opacity: i < cubes.floor() ? 1 : 0.45),
                          ),
                        if (cubes > 6) Text(' …', style: T.body(14, color: C.soft)),
                        const SizedBox(width: 8),
                        Text('≈ ${teaspoons(_grams)}', style: T.body(14, color: C.soft)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('1 teaspoon = 4 g', style: T.body(12, color: C.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Or pick what it was', style: T.body(14, color: C.muted)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.7,
                children: [
                  for (final p in _picks)
                    Semantics(
                      selected: _pick == p,
                      child: TextButton(
                        onPressed: () => _choose(p),
                        style: TextButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          backgroundColor: _pick == p ? const Color(0xFF1C1A2E) : Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _pick == p ? C.crystalLeft : C.line)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: T.body(15, color: C.text, weight: FontWeight.w600, height: 1.2)),
                            Text('≈ ${p.grams} g', style: T.body(12, color: C.muted, height: 1.3)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Pill(label: 'Add $_grams g to my crystal', background: C.crystalLeft, foreground: C.night, onPressed: _add),
              Center(child: TextButton(onPressed: _skip, child: Text('Not sure, skip this', style: T.body(15)))),
            ],
          ),
        ),
      ),
    );
  }
}

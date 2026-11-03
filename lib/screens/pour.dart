import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../state.dart';
import '../sugar.dart';
import '../theme.dart';
import 'slip.dart';

// Rough, deliberately round estimates; pouring is there to correct them.
const _picks = [('Chai', 8), ('Soda', 35), ('Dessert', 30), ('Chocolate', 25)];

/// "Pour in what you had": hold to pour sugar into a pile, a teaspoon at a
/// time. Then, if the night still needs deciding, the moon / new-sky choice.
class PourScreen extends StatefulWidget {
  const PourScreen({super.key, required this.state, required this.day});
  final AppState state;
  final DateTime day;

  @override
  State<PourScreen> createState() => _PourScreenState();
}

class _PourScreenState extends State<PourScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick)..start();
  double _time = 0;
  int _grams = 0;
  String? _label;
  final _added = <int>[];

  // While holding: when it started and the grams before it.
  double? _holdStart;
  int _holdBase = 0;
  double _burstUntil = 0;

  AppState get s => widget.state;

  bool get _needsDecision => s.pendingDay == widget.day && (s.lastDay == null || s.lastDay!.isBefore(widget.day));
  bool get _pouring => _holdStart != null || _time < _burstUntil;

  @override
  void initState() {
    super.initState();
    // Screenshot helper: show a pour in progress.
    if (AppState.demo && const String.fromEnvironment('SCREEN') == 'pour') {
      _grams = 24;
      _label = 'Chai';
      _burstUntil = double.infinity;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    setState(() {
      _time = elapsed.inMicroseconds / 1e6;
      if (_holdStart != null) {
        final grams = (_holdBase + _spoonsHeld(_time - _holdStart!) * 4).clamp(0, 400);
        if (grams > _grams) HapticFeedback.selectionClick();
        _grams = grams;
      }
    });
  }

  /// Slow at first so a teaspoon or two is easy, then faster for big amounts.
  static int _spoonsHeld(double held) {
    if (held < 0.25) return 0;
    final t = held - 0.25;
    return t < 2 ? 1 + (t / 0.5).floor() : 5 + ((t - 2) / 0.22).floor();
  }

  void _holdDown() {
    _holdStart = _time;
    _holdBase = _grams;
  }

  void _holdUp() {
    if (_holdStart == null) return;
    // A quick tap pours a single teaspoon.
    if (_grams == _holdBase && _grams < 400) {
      _grams += 4;
      _burstUntil = _time + 0.5;
      HapticFeedback.selectionClick();
    }
    _added.add(_grams - _holdBase);
    _holdStart = null;
  }

  void _pick((String, int) p) {
    HapticFeedback.selectionClick();
    final add = (p.$2).clamp(0, 400 - _grams);
    _grams += add;
    _added.add(add);
    _label = p.$1;
    _burstUntil = _time + 0.8;
  }

  void _undo() {
    if (_added.isEmpty) return;
    HapticFeedback.selectionClick();
    _grams -= _added.removeLast();
    if (_grams == 0) _label = null;
  }

  void _done() {
    s.logSugar(widget.day, _grams, label: _label);
    if (_needsDecision) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SlipScreen(state: s, day: widget.day, initialTag: logCategories[_label]),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _skip() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SlipScreen(state: s, day: widget.day),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: const CloseButton(color: C.soft),
        title: Text(
          'Pour in what you had',
          style: T.body(16, color: C.text, weight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(
            children: [
              Semantics(
                liveRegion: true,
                child: Column(
                  children: [
                    Text(formatGrams(_grams), style: T.display(64, height: 1)),
                    const SizedBox(height: 6),
                    Text(
                      _grams == 0 ? 'Hold the button to pour' : '${teaspoons(_grams)}${_label == null ? '' : ' · ${_label!.toLowerCase()}'}',
                      style: T.body(15),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final floor = box.maxHeight - 8;
                    return ExcludeSemantics(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(painter: GrainPilePainter(grams: _grams, reference: 200)),
                          ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: SpoonPainter(time: _time, pouring: _pouring && !still, streamTo: Offset(box.maxWidth / 2, floor - 10)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final p in _picks) _chip(p.$1, () => setState(() => _pick(p))),
                  if (_added.isNotEmpty) _chip('Undo', () => setState(_undo), icon: Icons.undo_rounded),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: 'Hold to pour sugar, a teaspoon at a time',
                      excludeSemantics: true,
                      onTap: () => setState(() {
                        _holdDown();
                        _holdUp();
                      }),
                      child: Listener(
                        onPointerDown: (_) => setState(_holdDown),
                        onPointerUp: (_) => setState(_holdUp),
                        onPointerCancel: (_) => setState(_holdUp),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _holdStart != null ? C.crystalLeft : C.text,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [BoxShadow(color: const Color(0xFFC9BEF0).withValues(alpha: 0.25), blurRadius: 40)],
                          ),
                          child: Text(
                            _holdStart != null ? 'Pouring…' : 'Hold to pour',
                            style: T.body(17, color: C.night, weight: FontWeight.w600, height: 1),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 104,
                    child: Pill(label: 'Done', outlined: true, height: 64, onPressed: _grams > 0 ? _done : null),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (_needsDecision)
                TextButton(
                  onPressed: _skip,
                  child: Text('Not sure how much? Skip this', style: T.body(14, color: C.muted)),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text('A tap is one teaspoon. Hold to pour more.', style: T.body(13, color: C.muted)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap, {IconData? icon}) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: StadiumBorder(side: BorderSide(color: _label == label ? C.crystalLeft : C.dim)),
        backgroundColor: _label == label ? const Color(0xFF1C1A2E) : Colors.transparent,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 15, color: C.soft), const SizedBox(width: 4)],
          Text(label, style: T.body(14, color: C.soft, height: 1)),
        ],
      ),
    );
  }
}

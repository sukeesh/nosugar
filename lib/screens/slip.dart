import 'package:flutter/material.dart';

import '../sky.dart';
import '../state.dart';
import '../theme.dart';
import 'home.dart';

const slipTags = ['Sweet drink', 'Dessert', 'Snack', 'Hidden in food'];

/// A slip, told kindly: a crystal formed. Spend a moon to dissolve it, or keep
/// it and start a new constellation. Either way the old stars stay.
class SlipScreen extends StatefulWidget {
  const SlipScreen({super.key, required this.state, required this.day, this.initialTag});
  final AppState state;
  final DateTime day;
  final String? initialTag;

  @override
  State<SlipScreen> createState() => _SlipScreenState();
}

class _SlipScreenState extends State<SlipScreen> {
  late String? _tag = slipTags.contains(widget.initialTag) ? widget.initialTag : null;

  AppState get s => widget.state;

  void _finish(bool useMoon) {
    s.recordSlip(widget.day, tag: _tag, useMoon: useMoon);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final when = nightName(s, widget.day);
    final streak = s.streak;
    final canMoon = s.moons > 0 && streak > 0;
    final repeat = _tag == null ? 0 : s.slipsTagged(_tag!);
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, leading: const BackButton(color: C.soft)),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 112,
                height: 112,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: C.crystalLeft.withValues(alpha: 0.07)),
                child: const CrystalIcon(size: 70),
              ),
              const SizedBox(height: 20),
              Text(when == 'today' ? 'A crystal formed today.' : 'A crystal formed $when.', style: T.display(36, height: 1.05)),
              const SizedBox(height: 12),
              Text(
                streak > 0
                    ? 'It doesn\'t erase your $streak ${streak == 1 ? 'star' : 'stars'}. Thanks for being honest, that\'s what makes the sky real.'
                    : 'Thanks for being honest. Tomorrow night is a fresh sky.',
                style: T.body(16),
              ),
              const SizedBox(height: 28),
              Text('What was it?', style: T.body(14, color: C.muted)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 3.4,
                children: [
                  for (final t in slipTags)
                    Semantics(
                      selected: _tag == t,
                      child: TextButton(
                        onPressed: () => setState(() => _tag = _tag == t ? null : t),
                        style: TextButton.styleFrom(
                          backgroundColor: _tag == t ? C.moon : Colors.transparent,
                          foregroundColor: _tag == t ? C.night : C.text,
                          shape: StadiumBorder(side: BorderSide(color: _tag == t ? C.moon : C.dim)),
                        ),
                        child: Text(t, style: T.body(15, color: _tag == t ? C.night : C.text, weight: _tag == t ? FontWeight.w600 : FontWeight.w400)),
                      ),
                    ),
                ],
              ),
              if (repeat >= 2)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text('That\'s ${repeat + 1} times it\'s been ${_tag!.toLowerCase()}. Next time it calls, tap Craving first.', style: T.body(14, color: C.muted)),
                ),
              const Spacer(),
              if (canMoon) ...[
                Pill(
                  label: 'Spend a moon to dissolve it',
                  sublabel: 'Keeps your $streak ${streak == 1 ? 'night' : 'nights'} · ${s.moons - 1} ${s.moons - 1 == 1 ? 'moon' : 'moons'} left',
                  background: C.moon,
                  foreground: C.night,
                  icon: const Icon(Icons.nightlight_round, size: 18, color: C.night),
                  onPressed: () => _finish(true),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => _finish(false),
                    child: Text('Keep it and start a new constellation', style: T.body(15)),
                  ),
                ),
              ] else ...[
                if (streak > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('No moons yet. You earn one every 7 clean nights.', style: T.body(14, color: C.muted)),
                  ),
                Pill(
                  label: streak > 0 ? 'Start a new constellation' : 'Start fresh tomorrow',
                  background: C.moon,
                  foreground: C.night,
                  onPressed: () => _finish(false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

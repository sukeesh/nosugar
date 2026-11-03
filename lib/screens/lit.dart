import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sky.dart';
import '../state.dart';
import '../theme.dart';
import 'streak_share.dart';

/// The reward: tonight's crystal shatters and its shards fall into a star.
class LitScreen extends StatefulWidget {
  const LitScreen({super.key, required this.state, required this.result});
  final AppState state;
  final LightResult result;

  @override
  State<LitScreen> createState() => _LitScreenState();
}

class _LitScreenState extends State<LitScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  bool _burstBuzzed = false, _starBuzzed = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (!_burstBuzzed && _c.value > 0.3) {
        _burstBuzzed = true;
        HapticFeedback.mediumImpact();
      }
      if (!_starBuzzed && _c.value > 0.7) {
        _starBuzzed = true;
        HapticFeedback.heavyImpact();
      }
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _share() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StreakShareScreen(state: widget.state, initial: widget.result.milestone != null ? StreakCard.milestone : StreakCard.constellation),
      ),
    );
  }

  String get _subtitle {
    final r = widget.result;
    if (r.earnedMoon) return 'You earned a moon.\nSpend it someday to forgive a slip.';
    if (r.milestone != null) return '${r.milestone!.name}. ${r.milestone!.note}';
    if (r.newBest) return 'A new personal best.\nThis is the longest your sky has ever been.';
    if (r.toBeatBest > 0 && r.toBeatBest <= 10) {
      return 'Tonight\'s crystal dissolved.\n${r.toBeatBest} more ${r.toBeatBest == 1 ? 'night' : 'nights'} and you pass your best.';
    }
    if (r.starNumber == 1) return 'Your first crystal dissolved.\nA constellation starts with one.';
    return 'Tonight\'s crystal dissolved.\nYour sky is a little brighter.';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final toMoon = s.current.stars % 7;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final textIn = Curves.easeOut.transform(((_c.value - 0.65) / 0.35).clamp(0, 1));
              return Column(
                children: [
                  const Spacer(),
                  SizedBox(
                    width: 320,
                    height: 320,
                    child: CustomPaint(painter: BurstPainter(_c.value, seed: widget.result.starNumber)),
                  ),
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: textIn,
                    child: Transform.translate(
                      offset: Offset(0, 12 * (1 - textIn)),
                      child: Column(
                        children: [
                          Text('Star ${widget.result.starNumber} is lit.', textAlign: TextAlign.center, style: T.display(38, height: 1.05)),
                          const SizedBox(height: 12),
                          Text(_subtitle, textAlign: TextAlign.center, style: T.body(16)),
                          const SizedBox(height: 32),
                          if (s.moons >= maxMoons)
                            Text('Moon pouch full: ${s.moons} moons saved', style: T.body(14, color: C.muted))
                          else ...[
                            Semantics(
                              label: '$toMoon of 7 nights toward your next moon',
                              excludeSemantics: true,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (var i = 0; i < 7; i++)
                                    Container(
                                      width: 22,
                                      height: 6,
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(3),
                                        color: i < toMoon || (toMoon == 0 && widget.result.earnedMoon) ? C.moon : C.line,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.result.earnedMoon
                                  ? 'Moon earned · ${s.moons} saved'
                                  : '${7 - toMoon} ${7 - toMoon == 1 ? 'night' : 'nights'} to your next moon',
                              style: T.body(14, color: C.muted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Opacity(
                    opacity: textIn,
                    child: Column(
                      children: [
                        Pill(
                          label: 'Share my streak',
                          icon: const Icon(Icons.ios_share_rounded, size: 18, color: C.ink),
                          onPressed: textIn > 0.5 ? _share : null,
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: textIn > 0.5 ? () => Navigator.of(context).pop() : null,
                          style: TextButton.styleFrom(minimumSize: const Size(double.infinity, 52), shape: const StadiumBorder()),
                          child: Text(
                            'Good night',
                            style: T.body(16, color: C.soft, weight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

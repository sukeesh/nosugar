import 'package:flutter/material.dart';

import '../hold_button.dart';
import '../reminders.dart';
import '../sky.dart';
import '../state.dart';
import '../theme.dart';
import 'lit.dart';
import 'scan.dart';
import 'sky_screen.dart';
import 'slip.dart';
import 'streak_share.dart';
import 'sos.dart';
import 'sugar_log.dart';
import 'grow.dart';
import 'share_card.dart';

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String nightName(AppState s, DateTime d) {
  if (d == s.today) return 'today';
  if (d == addDays(s.today, -1)) return 'yesterday';
  return _weekdays[d.weekday - 1];
}

/// Tonight and Sky tabs, with the craving SOS in the middle of the bar.
class Shell extends StatefulWidget {
  const Shell({super.key, required this.state});
  final AppState state;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Reminders.reschedule(widget.state);
    if (AppState.demo) WidgetsBinding.instance.addPostFrameCallback((_) => _openDemoScreen());
  }

  /// Screenshot helper: `--dart-define=DEMO=true --dart-define=SCREEN=sos`.
  void _openDemoScreen() {
    const screen = String.fromEnvironment('SCREEN');
    final s = widget.state;
    final nav = Navigator.of(context);
    switch (screen) {
      case 'sky' || 'sugar':
        setState(() => _tab = 1);
      case 'log':
        nav.push(
          MaterialPageRoute(
            builder: (_) => SugarLogScreen(state: s, day: s.today),
          ),
        );
      case 'grow':
        final before = s.gramsEaten(year: s.today.year);
        s.logSugar(s.today, 30);
        nav.push(
          MaterialPageRoute(
            builder: (_) => GrowScreen(state: s, day: s.today, added: 30, before: before),
          ),
        );
      case 'streak':
        nav.push(MaterialPageRoute(builder: (_) => StreakShareScreen(state: s)));
      case 'streak2':
        nav.push(
          MaterialPageRoute(
            builder: (_) => StreakShareScreen(state: s, initial: StreakCard.number),
          ),
        );
      case 'streak3':
        nav.push(
          MaterialPageRoute(
            builder: (_) => StreakShareScreen(state: s, initial: StreakCard.milestone),
          ),
        );
      case 'share':
        nav.push(MaterialPageRoute(builder: (_) => ShareCardScreen(state: s)));
      case 'sos':
        _openSos();
      case 'scan':
        nav.push(MaterialPageRoute(builder: (_) => const ScanScreen()));
      case 'slip':
        nav.push(
          MaterialPageRoute(
            builder: (_) => SlipScreen(state: s, day: s.today),
          ),
        );
      case 'lit':
        nav.push(
          MaterialPageRoute(
            builder: (_) => LitScreen(state: s, result: s.lightNight(s.today)),
          ),
        );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // The app may sit in memory past midnight: refresh "today" on resume.
    if (s == AppLifecycleState.resumed) {
      widget.state.closeLongGapsIfNeeded();
      setState(() {});
    }
  }

  void _openScan() => Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const ScanScreen()));

  Future<void> _openSos() async {
    final passed = await Navigator.of(context).push<bool>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const SosScreen()));
    if (passed == true && mounted) {
      widget.state.beatCraving();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('+1 shooting star. ${widget.state.cravingsBeaten} cravings outlasted.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          TonightTab(state: widget.state),
          SkyScreen(state: widget.state),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF1E2540))),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _NavItem(
                  icon: Icon(Icons.star_rounded, color: _tab == 0 ? C.gold : C.muted, size: 24),
                  label: 'Tonight',
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Craving SOS',
                    excludeSemantics: true,
                    child: InkResponse(
                      onTap: _openSos,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 30,
                            decoration: BoxDecoration(
                              color: C.sosSurface,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: C.sosLine),
                            ),
                            child: const Icon(Icons.waves_rounded, color: C.sos, size: 20),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Craving',
                            style: T.body(12, color: C.sos, weight: FontWeight.w600, height: 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _NavItem(
                  icon: const CrystalIcon(size: 22),
                  label: 'Check food',
                  semanticLabel: 'Check food for hidden sugar',
                  color: C.soft,
                  selected: false,
                  onTap: _openScan,
                ),
                _NavItem(
                  icon: Icon(Icons.auto_awesome_outlined, color: _tab == 1 ? C.gold : C.muted, size: 24),
                  label: 'Sky',
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap, this.color, this.semanticLabel});
  final Widget icon;
  final String label;
  final String? semanticLabel;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? C.gold : this.color ?? C.muted;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: semanticLabel ?? label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 24, child: Center(child: icon)),
              const SizedBox(height: 4),
              Text(
                label,
                style: T.body(12, color: color, weight: selected ? FontWeight.w600 : FontWeight.w400, height: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TonightTab extends StatefulWidget {
  const TonightTab({super.key, required this.state});
  final AppState state;

  @override
  State<TonightTab> createState() => _TonightTabState();
}

class _TonightTabState extends State<TonightTab> with SingleTickerProviderStateMixin {
  late final AnimationController _twinkle = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  AppState get s => widget.state;

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  void _light(DateTime day) {
    final result = s.lightNight(day);
    Reminders.reschedule(s);
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) => LitScreen(state: s, result: result),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  /// Sugar first ("how much?"), then the cluster grows, then the night's choice.
  Future<void> _slip(DateTime day) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SugarLogScreen(state: s, day: day),
      ),
    );
    Reminders.reschedule(s);
  }

  /// Sugar was logged for this night but the moon / new-sky choice wasn't made.
  Future<void> _finish(DateTime day) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SlipScreen(state: s, day: day),
      ),
    );
    Reminders.reschedule(s);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final missed = s.missedDays;
        final day = s.pendingDay;
        final next = s.nextMilestone;
        return SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 16, 0),
                child: Row(
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: 'nosugar', style: T.display(21)),
                          TextSpan(
                            text: '.',
                            style: T.display(21, color: C.gold),
                          ),
                        ],
                      ),
                    ),
                    // Keeps the header the same height it had with the old scan button.
                    const SizedBox(height: 44),
                  ],
                ),
              ),
              Expanded(
                child: Semantics(
                  label: 'Your constellation: ${s.streak} stars${s.todayDone ? '' : ', with tonight\'s sugar crystal waiting'}',
                  child: AnimatedBuilder(
                    animation: _twinkle,
                    builder: (_, _) => CustomPaint(
                      painter: SkyPainter(constellation: s.current, showCrystal: !s.todayDone, twinkle: _twinkle.value, shootingStars: s.current.cravings),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: s.streak == 0
                    ? Text(s.past.isEmpty ? 'Tonight is\nnight one.' : 'A fresh sky.\nNight one.', style: T.display(48, height: 1.0))
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${s.streak}', style: T.display(112, height: 0.82)),
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(s.streak == 1 ? 'night\nsugar-free' : 'nights\nsugar-free', style: T.body(17, height: 1.3)),
                          ),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                child: Wrap(
                  spacing: 18,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.nightlight_round, size: 15, color: C.moon),
                        const SizedBox(width: 6),
                        Text(s.moons == 1 ? '1 moon' : '${s.moons} moons', style: T.body(14, color: C.muted)),
                      ],
                    ),
                    if (next != null)
                      Text('${next.name} in ${next.night - s.streak} ${next.night - s.streak == 1 ? 'night' : 'nights'}', style: T.body(14, color: C.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: s.todayDone
                    ? _DoneCard(state: s)
                    : Column(
                        children: [
                          if (missed.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Text(
                                'You didn\'t check in ${nightName(s, day) == 'yesterday' ? 'last night' : 'on ${nightName(s, day)}'}. Was ${nightName(s, day)} free of added sugar?',
                                textAlign: TextAlign.center,
                                style: T.body(15, color: C.text),
                              ),
                            ),
                          if (s.gramsOn(day) > 0) ...[
                            Text(
                              '${s.gramsOn(day)} g logged ${nightName(s, day) == 'today' ? 'today' : 'for ${nightName(s, day)}'}.',
                              style: T.body(15, color: C.text),
                            ),
                            const SizedBox(height: 14),
                            Pill(label: 'Finish tonight\'s check-in', background: C.moon, foreground: C.night, height: 64, onPressed: () => _finish(day)),
                            const SizedBox(height: 54),
                          ] else ...[
                            HoldButton(key: ValueKey(day), label: 'Hold to light star ${s.streak + 1}', onComplete: () => _light(day)),
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: () => _slip(day),
                              child: Text(missed.isNotEmpty ? 'No, I had added sugar' : 'I had added sugar today', style: T.body(15, color: C.soft)),
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard({required this.state});
  final AppState state;

  String get _line {
    final c = state.current;
    if (c.length == 0) return 'Fresh sky tomorrow night.';
    if (c.nights.last == Night.moon) return 'Moon spent. Night ${c.length} kept.';
    return 'Star ${c.length} is lit. See you tomorrow.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      margin: const EdgeInsets.only(bottom: 48),
      decoration: ShapeDecoration(
        shape: const StadiumBorder(side: BorderSide(color: C.line)),
        color: C.surface,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star_rounded, color: C.gold, size: 20),
          const SizedBox(width: 8),
          Text(
            _line,
            style: T.body(16, color: C.text, weight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

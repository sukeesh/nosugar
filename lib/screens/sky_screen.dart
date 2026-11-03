import 'package:flutter/material.dart';

import '../reminders.dart';
import '../sky.dart';
import '../state.dart';
import '../theme.dart';
import 'streak_share.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _range(Constellation c) {
  final a = _months[c.start.month - 1];
  if (c.end == null) return 'now';
  final b = _months[c.end!.month - 1];
  return a == b ? a : '$a–$b';
}

/// Every constellation ever made, plus the milestone track.
class SkyScreen extends StatefulWidget {
  const SkyScreen({super.key, required this.state});
  final AppState state;

  @override
  State<SkyScreen> createState() => _SkyScreenState();
}

class _SkyScreenState extends State<SkyScreen> {
  AppState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final s = state;
        final all = [s.current, ...s.past.reversed];
        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Row(
                children: [
                  Expanded(child: Text('Your sky', style: T.display(36))),
                  CircleIconButton(icon: Icons.tune_rounded, tooltip: 'Settings', onPressed: () => _settings(context, s)),
                ],
              ),
              const SizedBox(height: 4),
              ...[
                Text(
                  '${s.totalStars} ${s.totalStars == 1 ? 'night' : 'nights'} lit · ${s.cravingsBeaten} cravings outlasted · ${s.moons} ${s.moons == 1 ? 'moon' : 'moons'}',
                  style: T.body(15, color: C.muted),
                ),
                const SizedBox(height: 20),
                _MilestoneCard(state: s),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: all.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.98,
                  ),
                  itemBuilder: (context, i) {
                    final c = all[i];
                    final isCurrent = i == 0;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: C.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isCurrent ? C.gold : C.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: c.length == 0
                                ? Center(child: CrystalIcon(size: 26, opacity: 0.8))
                                : MiniSky(constellation: c, current: isCurrent, height: double.infinity),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  isCurrent ? 'Still rising' : c.name,
                                  style: T.body(15, color: C.text, weight: FontWeight.w600, height: 1.2),
                                ),
                              ),
                              if (isCurrent && c.length > 0)
                                SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Share your streak',
                                    icon: const Icon(Icons.ios_share_rounded, size: 18, color: C.gold),
                                    onPressed: () =>
                                        Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => StreakShareScreen(state: s))),
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            isCurrent && c.length == 0 ? 'starts tonight' : '${c.length} ${c.length == 1 ? 'night' : 'nights'} · ${_range(c)}',
                            style: T.body(13, color: C.muted, height: 1.3),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _settings(BuildContext context, AppState s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => ListenableBuilder(
        listenable: s,
        builder: (context, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  value: s.remindersOn,
                  activeThumbColor: C.gold,
                  title: Text('Nightly reminder', style: T.body(16, color: C.text)),
                  onChanged: (v) async {
                    if (v) await Reminders.requestPermission();
                    s.setReminder(on: v);
                    Reminders.reschedule(s);
                  },
                ),
                ListTile(
                  enabled: s.remindersOn,
                  title: Text('Reminder time', style: T.body(16, color: C.text)),
                  trailing: Text(
                    TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute).format(context),
                    style: T.body(16, color: C.gold),
                  ),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute),
                    );
                    if (t != null) {
                      s.setReminder(hour: t.hour, minute: t.minute);
                      Reminders.reschedule(s);
                    }
                  },
                ),
                ListTile(
                  title: Text('What counts as added sugar?', style: T.body(16, color: C.text)),
                  subtitle: Text('Sugar, honey, syrups, juice and sweets count. Whole fruit, plain milk and grains don\'t.', style: T.body(13, color: C.muted)),
                ),
                ListTile(
                  title: Text('Start over', style: T.body(16, color: const Color(0xFFFFB199))),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: C.surface,
                        title: Text('Erase your whole sky?', style: T.display(22)),
                        content: Text('Every constellation, moon and star will be gone. This can\'t be undone.', style: T.body(15)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Erase', style: TextStyle(color: Color(0xFFFFB199))),
                          ),
                        ],
                      ),
                    );
                    if (ok == true && context.mounted) {
                      Navigator.of(context).pop();
                      await s.resetAll();
                      Reminders.reschedule(s);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final streak = state.streak;
    final next = state.nextMilestone;
    final reached = milestones.lastWhere((m) => m.night <= streak, orElse: () => const Milestone(0, '', ''));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  next == null ? 'Every milestone reached' : 'Next: ${next.name}',
                  style: T.body(14, color: C.text, weight: FontWeight.w600),
                ),
              ),
              if (next != null) Text('${next.night - streak} to go', style: T.body(14, color: C.muted)),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) {
              // Dots sit evenly; progress fills between them by nights.
              final n = milestones.length;
              double xFor(int night) {
                if (night <= 0) return 0;
                for (var i = 0; i < n; i++) {
                  final m = milestones[i].night;
                  final prev = i == 0 ? 0 : milestones[i - 1].night;
                  if (night <= m) {
                    return (i - 1 + (night - prev) / (m - prev)).clamp(0, n - 1) / (n - 1) * (box.maxWidth - 12);
                  }
                }
                return box.maxWidth - 12;
              }

              final fill = xFor(streak);
              return SizedBox(
                height: 34,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(left: 6, right: 6, top: 5, child: Container(height: 2, color: C.line)),
                    Positioned(
                      left: 6,
                      top: 5,
                      child: Container(height: 2, width: fill, color: C.gold),
                    ),
                    for (var i = 0; i < n; i++)
                      Positioned(
                        left: i / (n - 1) * (box.maxWidth - 12) - 6,
                        top: 0,
                        width: 24,
                        child: Column(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: milestones[i].night <= streak ? C.gold : C.night,
                                border: Border.all(color: milestones[i] == next ? C.gold : (milestones[i].night <= streak ? C.gold : C.dim), width: 2),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('${milestones[i].night}', style: T.body(11, color: milestones[i] == next ? C.text : C.muted, height: 1)),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(reached.night > 0 ? reached.note : 'Light three stars in a row to pass the first milestone.', style: T.body(13, color: C.muted)),
        ],
      ),
    );
  }
}

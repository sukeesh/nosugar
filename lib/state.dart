import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A night in a constellation: a clean star, or a slip forgiven with a moon.
enum Night { star, moon }

class Constellation {
  Constellation({required this.name, required this.seed, required this.start, List<Night>? nights, this.end, this.endedByCrystal = false, this.cravings = 0})
      : nights = [...?nights];

  final String name;
  final int seed;
  final DateTime start;
  final List<Night> nights;
  DateTime? end;
  bool endedByCrystal;
  int cravings;

  int get length => nights.length;
  int get stars => nights.where((n) => n == Night.star).length;

  Map<String, dynamic> toJson() => {
        'name': name,
        'seed': seed,
        'start': dayKey(start),
        'end': end == null ? null : dayKey(end!),
        'nights': nights.map((n) => n.index).toList(),
        'crystal': endedByCrystal,
        'cravings': cravings,
      };

  factory Constellation.fromJson(Map<String, dynamic> j) => Constellation(
        name: j['name'],
        seed: j['seed'],
        start: parseDay(j['start']),
        end: j['end'] == null ? null : parseDay(j['end']),
        nights: (j['nights'] as List).map((i) => Night.values[i as int]).toList(),
        endedByCrystal: j['crystal'] ?? false,
        cravings: j['cravings'] ?? 0,
      );
}

class Slip {
  Slip(this.day, this.tag);
  final DateTime day;
  final String? tag;
  Map<String, dynamic> toJson() => {'day': dayKey(day), 'tag': tag};
  factory Slip.fromJson(Map<String, dynamic> j) => Slip(parseDay(j['day']), j['tag']);
}

/// Added sugar the person told us they ate. Every log is an honest one.
class SugarLog {
  SugarLog(this.day, this.grams, {this.label});
  final DateTime day;
  final int grams;
  final String? label;
  Map<String, dynamic> toJson() => {'day': dayKey(day), 'g': grams, 'label': label};
  factory SugarLog.fromJson(Map<String, dynamic> j) => SugarLog(parseDay(j['day']), j['g'], label: j['label']);
}

class Milestone {
  const Milestone(this.night, this.name, this.note);
  final int night;
  final String name;
  final String note;
}

const milestones = [
  Milestone(3, 'The hump', 'Cravings are often loudest in the first days. You got through them.'),
  Milestone(7, 'First moon', 'A full week. Every 7 clean nights earns a moon to forgive one slip.'),
  Milestone(14, 'Taste shift', 'Many people find fruit starts tasting sweeter around now.'),
  Milestone(30, 'Clear Sky', 'A whole month. Sugar is starting to feel optional.'),
  Milestone(66, 'New normal', 'Around here, a habit usually stops feeling like effort.'),
  Milestone(100, 'Supernova', 'One hundred nights. Your whole sky is lit.'),
];

const _names = [
  'First Spark', 'The Kite', 'The Lantern', 'The Heron', 'The Long Light', 'The Compass', 'The River',
  'The Comet', 'The Orchard', 'The Harbor', 'The Ember', 'The Arrow', 'The Willow', 'The Bell', 'The Tide',
];

const maxMoons = 3;

String dayKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime parseDay(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

class LightResult {
  LightResult({required this.starNumber, required this.earnedMoon, required this.milestone, required this.pastBest});
  final int starNumber;
  final bool earnedMoon;
  final Milestone? milestone;

  /// Longest finished constellation, 0 if none.
  final int pastBest;
  bool get newBest => pastBest > 0 && starNumber == pastBest + 1;
  int get toBeatBest => pastBest + 1 - starNumber;
}

class AppState extends ChangeNotifier {
  static const _key = 'nosugar.v1';
  static const demo = bool.fromEnvironment('DEMO');

  late SharedPreferences _prefs;

  bool onboarded = false;
  late Constellation current;
  List<Constellation> past = [];
  int moons = 0;
  int cravingsBeaten = 0;
  DateTime? lastDay;
  List<Slip> slips = [];
  int reminderHour = 21;
  int reminderMinute = 0;
  bool remindersOn = true;
  List<SugarLog> sugarLogs = [];

  /// Days a star was lit (clean nights), used for "sugar skipped" per year.
  List<DateTime> starDays = [];

  /// Added sugar per day before nosugar, from onboarding. Null = not asked yet.
  int? baselineGrams;
  bool baselineAsked = false;

  /// Overridable clock for testing.
  DateTime Function() clock = DateTime.now;

  DateTime get today => dateOnly(clock());
  int get streak => current.length;
  int get best => [streak, ...past.map((c) => c.length)].reduce(max);
  int get totalStars => current.length + past.fold(0, (s, c) => s + c.length);
  bool get todayDone => lastDay != null && !lastDay!.isBefore(today);

  /// Nights that ended without a check-in, oldest first (never includes today).
  List<DateTime> get missedDays {
    if (lastDay == null) return [];
    final out = <DateTime>[];
    for (var d = addDays(lastDay!, 1); d.isBefore(today); d = addDays(d, 1)) {
      out.add(d);
    }
    return out;
  }

  /// The day the next check-in is about: the oldest missed night, else today.
  DateTime get pendingDay => missedDays.isNotEmpty ? missedDays.first : today;

  Milestone? get nextMilestone {
    for (final m in milestones) {
      if (m.night > streak) return m;
    }
    return null;
  }

  int get nextMoonIn => 7 - (current.stars % 7);

  /// Grams logged in [year], or ever when null.
  int gramsEaten({int? year}) => sugarLogs.where((l) => year == null || l.day.year == year).fold(0, (s, l) => s + l.grams);
  int honestLogs({int? year}) => sugarLogs.where((l) => year == null || l.day.year == year).length;
  int gramsOn(DateTime day) => sugarLogs.where((l) => l.day == day).fold(0, (s, l) => s + l.grams);
  int cleanNights({int? year}) => starDays.where((d) => year == null || d.year == year).length;

  /// Sugar the person would have eaten on their clean nights at their old habit.
  int? gramsSkipped({int? year}) => baselineGrams == null ? null : baselineGrams! * cleanNights(year: year);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString(_key);
    if (raw != null) {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      onboarded = j['onboarded'] ?? false;
      current = Constellation.fromJson(j['current']);
      past = (j['past'] as List).map((e) => Constellation.fromJson(e)).toList();
      moons = j['moons'] ?? 0;
      cravingsBeaten = j['cravingsBeaten'] ?? 0;
      lastDay = j['lastDay'] == null ? null : parseDay(j['lastDay']);
      slips = ((j['slips'] ?? []) as List).map((e) => Slip.fromJson(e)).toList();
      reminderHour = j['reminderHour'] ?? 21;
      reminderMinute = j['reminderMinute'] ?? 0;
      remindersOn = j['remindersOn'] ?? true;
      sugarLogs = ((j['sugarLogs'] ?? []) as List).map((e) => SugarLog.fromJson(e)).toList();
      baselineGrams = j['baselineGrams'];
      baselineAsked = j['baselineAsked'] ?? false;
      final days = j['starDays'] as List?;
      starDays = days == null ? _legacyStarDays() : days.map((e) => parseDay(e)).toList();
    } else {
      current = _newConstellation(today);
      if (demo) _seedDemo();
    }
    _closeLongGaps();
  }

  Future<void> _save() async {
    await _prefs.setString(
      _key,
      jsonEncode({
        'onboarded': onboarded,
        'current': current.toJson(),
        'past': past.map((c) => c.toJson()).toList(),
        'moons': moons,
        'cravingsBeaten': cravingsBeaten,
        'lastDay': lastDay == null ? null : dayKey(lastDay!),
        'slips': slips.map((s) => s.toJson()).toList(),
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
        'remindersOn': remindersOn,
        'sugarLogs': sugarLogs.map((l) => l.toJson()).toList(),
        'baselineGrams': baselineGrams,
        'baselineAsked': baselineAsked,
        'starDays': starDays.map(dayKey).toList(),
      }),
    );
  }

  void _commit() {
    notifyListeners();
    _save();
  }

  Constellation _newConstellation(DateTime start) =>
      Constellation(name: _names[past.length % _names.length], seed: Random().nextInt(1 << 30), start: start);

  /// After a week of silence we stop asking about each night: the constellation
  /// closes quietly (no crystal, nobody slipped) and a fresh one begins.
  void closeLongGapsIfNeeded() => _closeLongGaps();

  void _closeLongGaps() {
    if (missedDays.length > 7) {
      if (current.length > 0) {
        current.end = lastDay;
        past.add(current);
      }
      current = _newConstellation(today);
      lastDay = addDays(today, -1);
      _commit();
    }
  }

  void finishOnboarding() {
    onboarded = true;
    _commit();
  }

  LightResult lightNight(DateTime day) {
    current.nights.add(Night.star);
    starDays.add(day);
    lastDay = day;
    var earnedMoon = false;
    if (current.stars % 7 == 0 && moons < maxMoons) {
      moons++;
      earnedMoon = true;
    }
    Milestone? hit;
    for (final m in milestones) {
      if (m.night == current.length) hit = m;
    }
    _commit();
    return LightResult(
      starNumber: current.length,
      earnedMoon: earnedMoon,
      milestone: hit,
      pastBest: past.fold(0, (m, c) => max(m, c.length)),
    );
  }

  void recordSlip(DateTime day, {String? tag, required bool useMoon}) {
    slips.add(Slip(day, tag));
    if (useMoon && moons > 0 && current.length > 0) {
      moons--;
      current.nights.add(Night.moon);
    } else {
      if (current.length > 0) {
        current
          ..end = day
          ..endedByCrystal = true;
        past.add(current);
      }
      current = _newConstellation(addDays(day, 1));
    }
    lastDay = day;
    _commit();
  }

  int slipsTagged(String tag) => slips.where((s) => s.tag == tag).length;

  void logSugar(DateTime day, int grams, {String? label}) {
    if (grams <= 0) return;
    sugarLogs.add(SugarLog(day, grams, label: label));
    _commit();
  }

  void setBaseline(int? grams) {
    baselineGrams = grams;
    baselineAsked = true;
    _commit();
  }

  /// Installs from before star days were recorded: assume the lit nights ran
  /// back-to-back up to the last check-in.
  List<DateTime> _legacyStarDays() {
    final n = totalStars;
    if (n == 0 || lastDay == null) return [];
    return [for (var i = n - 1; i >= 0; i--) addDays(lastDay!, -i)];
  }

  void beatCraving() {
    cravingsBeaten++;
    current.cravings++;
    _commit();
  }

  void setReminder({int? hour, int? minute, bool? on}) {
    reminderHour = hour ?? reminderHour;
    reminderMinute = minute ?? reminderMinute;
    remindersOn = on ?? remindersOn;
    _commit();
  }

  Future<void> resetAll() async {
    past = [];
    moons = 0;
    cravingsBeaten = 0;
    lastDay = null;
    slips = [];
    sugarLogs = [];
    starDays = [];
    baselineGrams = null;
    baselineAsked = false;
    current = _newConstellation(today);
    onboarded = false;
    _commit();
  }

  void _seedDemo() {
    onboarded = true;
    past = [
      Constellation(name: 'First Spark', seed: 11, start: addDays(today, -110), end: addDays(today, -106), nights: List.filled(4, Night.star), endedByCrystal: true),
      Constellation(name: 'The Kite', seed: 23, start: addDays(today, -95), end: addDays(today, -86), nights: List.filled(9, Night.star), endedByCrystal: true),
      Constellation(name: 'The Long Light', seed: 37, start: addDays(today, -70), end: addDays(today, -29), nights: [...List.filled(20, Night.star), Night.moon, ...List.filled(20, Night.star)], endedByCrystal: true),
    ];
    current = Constellation(name: 'The Lantern', seed: 4242, start: addDays(today, -23), nights: List.filled(23, Night.star), cravings: 4);
    moons = 2;
    cravingsBeaten = 31;
    lastDay = addDays(today, -1);
    starDays = [for (var i = 77; i >= 1; i--) addDays(today, -i)];
    baselineGrams = 30;
    baselineAsked = true;
    sugarLogs = [
      for (var i = 0; i < 11; i++) SugarLog(addDays(today, -200 + i * 17), 112, label: 'Dessert'),
      SugarLog(addDays(today, -3), 8, label: 'Chai'),
    ];
  }
}

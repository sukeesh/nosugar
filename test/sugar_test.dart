import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nosugar/crystal.dart';
import 'package:nosugar/state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('sugar wording', () {
    test('packets in quarters', () {
      expect(packets(1240), '1¼ packets');
      expect(packets(250), '¼ packet');
      expect(packets(2000), '2 packets');
      expect(packets(90), 'less than a quarter packet');
    });

    test('teaspoons in halves', () {
      expect(teaspoons(10), '2½ teaspoons');
      expect(teaspoons(8), '2 teaspoons');
      expect(teaspoons(4), '1 teaspoon');
      expect(teaspoons(2), '½ teaspoon');
    });

    test('weighs like the closest everyday thing', () {
      expect(weighsLike(1240), 'about as heavy as a pineapple');
      expect(weighsLike(2310), 'about as heavy as a 2-litre bottle of water');
      expect(weighsLike(40), isNull);
    });

    test('grams format', () {
      expect(formatGrams(240), '240 g');
      expect(formatGrams(1240), '1.24 kg');
      expect(formatGrams(2500), '2.5 kg');
      expect(formatGrams(10000), '10 kg');
    });

    test('levels', () {
      expect(levelFor(100).name, 'Shard');
      expect(levelFor(1240).name, 'Cluster');
      expect(nextLevel(1240)!.name, 'Geode');
      expect(nextLevel(20000), isNull);
    });
  });

  group('sugar state', () {
    late AppState s;
    late DateTime now;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      now = DateTime(2026, 10, 1, 21);
      s = AppState()..clock = () => now;
      await s.load();
    });

    test('skipped = old habit × clean nights, moon nights excluded', () {
      s.setBaseline(30);
      for (var i = 0; i < 7; i++) {
        s.lightNight(s.today);
        now = now.add(const Duration(days: 1));
      }
      s.logSugar(s.today, 12);
      s.recordSlip(s.today, useMoon: true);
      expect(s.gramsSkipped(year: 2026), 7 * 30);
      expect(s.gramsEaten(year: 2026), 12);
      expect(s.honestLogs(), 1);
      expect(s.gramsSkipped(year: 2025), 0);
    });

    test('no baseline means no skipped figure', () {
      s.lightNight(s.today);
      expect(s.gramsSkipped(), isNull);
    });

    test('old installs get star days rebuilt from their streak', () async {
      SharedPreferences.setMockInitialValues({
        'nosugar.v1': jsonEncode({
          'onboarded': true,
          'current': {'name': 'First Spark', 'seed': 1, 'start': '2026-09-28', 'end': null, 'nights': [0, 0, 0], 'crystal': false, 'cravings': 0},
          'past': [],
          'lastDay': '2026-09-30',
        }),
      });
      final old = AppState()..clock = () => now;
      await old.load();
      expect(old.starDays.map(dayKey), ['2026-09-28', '2026-09-29', '2026-09-30']);
    });
  });
}

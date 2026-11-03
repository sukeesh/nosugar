import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nosugar/state.dart';
import 'package:nosugar/sugar.dart';
import 'package:nosugar/sugar_names.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('sugar wording', () {
    test('teaspoons in halves', () {
      expect(teaspoons(10), '2½ teaspoons');
      expect(teaspoons(8), '2 teaspoons');
      expect(teaspoons(4), '1 teaspoon');
      expect(teaspoons(2), '½ teaspoon');
    });

    test('grams format', () {
      expect(formatGrams(240), '240 g');
      expect(formatGrams(1240), '1.24 kg');
      expect(formatGrams(2500), '2.5 kg');
      expect(formatGrams(10000), '10 kg');
    });

    test('sugar pile shape', () {
      expect(moundAt(0), 1);
      expect(moundAt(1), 0);
      expect(moundAt(-0.5), moundAt(0.5));
    });

    test('names list leaves out plain "sugar"', () {
      expect(sugarNames, contains('jaggery'));
      expect(sugarNames, contains('maltodextrin'));
      expect(sugarNames, isNot(contains('sugar')));
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

    test('month filter and categories', () {
      s.setBaseline(20);
      s.lightNight(s.today);
      now = DateTime(2026, 11, 2, 21);
      s.logSugar(s.today, 35, label: 'Soda');
      s.recordSlip(s.today, tag: 'Dessert', useMoon: false);
      s.logSugar(addDays(s.today, -1), 8, label: 'Chai');
      expect(s.gramsEaten(year: 2026, month: 11), 43);
      expect(s.gramsEaten(year: 2026, month: 10), 0);
      expect(s.gramsSkipped(year: 2026, month: 10), 20);
      expect(s.gramsSkipped(year: 2026, month: 11), 0);
      // The slip tag picked that night wins over the quick pick's guess.
      expect(s.sugarCategory(s.logsIn(month: 11).first), 'Dessert');
      expect(s.sugarCategory(s.logsIn(month: 11).last), 'Sweet drink');
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

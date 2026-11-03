import 'package:flutter_test/flutter_test.dart';
import 'package:nosugar/state.dart';
import 'package:nosugar/sugar_names.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('findSugars', () {
    test('finds hidden names and prefers the longest match', () {
      final hits = findSugars('INGREDIENTS: Rolled oats, brown rice syrup, almonds, dextrose, sunflower oil, maltodextrin, sea salt.');
      expect(hits.where((h) => !h.watch).map((h) => h.name), ['Brown rice syrup', 'Dextrose']);
      expect(hits.where((h) => h.watch).map((h) => h.name), ['Maltodextrin']);
    });

    test('ignores "no added sugar" claims and nutrition rows', () {
      expect(findSugars('No added sugar! Ingredients: oats, milk. Total sugars 2g'), isEmpty);
    });

    test('ignores caramel colour but catches caramel', () {
      expect(findSugars('Ingredients: water, caramel colour'), isEmpty);
      expect(findSugars('Ingredients: caramel, nuts').single.name, 'Caramel');
    });

    test('joins words split across OCR lines', () {
      expect(findSugars('Ingredients: oats, glu-\ncose syrup').single.name, 'Glucose syrup');
    });
  });

  group('AppState', () {
    late AppState s;
    late DateTime now;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      now = DateTime(2026, 10, 1, 21);
      s = AppState()..clock = () => now;
      await s.load();
    });

    void nextDay() => now = now.add(const Duration(days: 1));

    test('every 7th clean night earns a moon, capped', () {
      for (var i = 0; i < 28; i++) {
        s.lightNight(s.today);
        nextDay();
      }
      expect(s.streak, 28);
      expect(s.moons, maxMoons);
    });

    test('a moon keeps the streak; no moon starts a new constellation', () {
      for (var i = 0; i < 7; i++) {
        s.lightNight(s.today);
        nextDay();
      }
      s.recordSlip(s.today, useMoon: true);
      expect(s.streak, 8);
      expect(s.moons, 0);
      nextDay();
      s.recordSlip(s.today, useMoon: true);
      expect(s.streak, 0);
      expect(s.past.single.length, 8);
      expect(s.past.single.endedByCrystal, isTrue);
    });

    test('missed nights are asked about oldest first', () {
      s.lightNight(s.today);
      nextDay();
      nextDay();
      nextDay();
      expect(s.missedDays.length, 2);
      expect(s.pendingDay, addDays(s.today, -2));
      s.lightNight(s.pendingDay);
      expect(s.pendingDay, addDays(s.today, -1));
    });

    test('a week of silence closes the constellation without a crystal', () {
      s.lightNight(s.today);
      for (var i = 0; i < 10; i++) {
        nextDay();
      }
      s.closeLongGapsIfNeeded();
      expect(s.streak, 0);
      expect(s.past.single.endedByCrystal, isFalse);
      expect(s.missedDays, isEmpty);
    });

    test('personal best is reported once', () {
      for (var i = 0; i < 3; i++) {
        s.lightNight(s.today);
        nextDay();
      }
      s.recordSlip(s.today, useMoon: false);
      nextDay();
      final results = <LightResult>[];
      for (var i = 0; i < 5; i++) {
        results.add(s.lightNight(s.today));
        nextDay();
      }
      expect(results.map((r) => r.newBest), [false, false, false, true, false]);
    });
  });
}

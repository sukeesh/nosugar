import 'package:flutter_test/flutter_test.dart';
import 'package:nosugar/screens/streak_share.dart';
import 'package:nosugar/state.dart';

void main() {
  AppState withStreak(int n) => AppState()..current = Constellation(name: 'Test', seed: 1, start: DateTime(2026, 10, 1), nights: List.filled(n, Night.star));

  test('milestone card uses the biggest milestone reached', () {
    expect(reachedMilestone(withStreak(2)), isNull);
    expect(reachedMilestone(withStreak(3))!.name, 'The hump');
    expect(reachedMilestone(withStreak(24))!.night, 14);
    expect(reachedMilestone(withStreak(30))!.name, 'Clear Sky');
    expect(reachedMilestone(withStreak(250))!.night, 100);
  });
}

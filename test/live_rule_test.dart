import 'package:flutter_test/flutter_test.dart';
import '../server/live_rule.dart';

void main() {
  final now = DateTime(2026, 10, 17, 12);

  Observation sample(String client, double distance, int secondsAgo, {bool confirmed = true}) {
    return Observation(
      clientId: client,
      dutyId: 7,
      date: '2026-10-17',
      distanceM: distance,
      lat: 28,
      lng: 77,
      at: now.subtract(Duration(seconds: secondsAgo)),
      confirmed: confirmed,
    );
  }

  test('two phones within two minutes publish the median', () {
    final fix = agree(
      [sample('a', 1000, 20), sample('b', 3000, 30)],
      dutyId: 7,
      date: '2026-10-17',
      now: now,
    );
    expect(fix, isNotNull);
    expect(fix!.distanceM, 2000);
    expect(fix.agreeing, 2);
  });

  test('one confirmed rider needs three on-route points', () {
    expect(
      agree(
        [sample('a', 10, 10), sample('a', 20, 30)],
        dutyId: 7,
        date: '2026-10-17',
        now: now,
      ),
      isNull,
    );
    final fix = agree(
      [sample('a', 10, 10), sample('a', 20, 30), sample('a', 40, 50)],
      dutyId: 7,
      date: '2026-10-17',
      now: now,
    );
    expect(fix!.distanceM, 10);
    expect(fix.agreeing, 1);
  });
}

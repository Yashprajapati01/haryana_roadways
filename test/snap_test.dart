import 'package:flutter_test/flutter_test.dart';
import 'package:haryana_roadways/locate/cell_table.dart';
import 'package:haryana_roadways/locate/snap.dart';

void main() {
  final t0 = DateTime(2026, 10, 17, 10);
  final t1 = DateTime(2026, 10, 17, 11);
  final line = [
    RouteStop(srNo: 1, name: 'A', time: t0, lat: 0, lng: 0),
    RouteStop(srNo: 2, name: 'B', time: t1, lat: 0, lng: 0.02),
  ];

  test('a point on a two-stop line snaps to the middle', () {
    final hit = snapToRoute(line, 0, 0.01, maxCrossTrackM: gpsCrossTrackM);
    expect(hit, isNotNull);
    expect(hit!.fraction, closeTo(0.5, 0.05));
    expect(hit.fromIndex, 0);
    expect(hit.toIndex, 1);
    expect(hit.crossTrackM, lessThan(50));
  });

  test('a point 5 km off the line is dropped', () {
    final hit = snapToRoute(line, 0.045, 0.01, maxCrossTrackM: gpsCrossTrackM);
    expect(hit, isNull);
  });

  test('the clock puts the bus between the surrounding stops', () {
    final stops = [
      RouteStop(srNo: 1, name: 'A', time: DateTime(2026, 10, 17, 10)),
      RouteStop(srNo: 2, name: 'B', time: DateTime(2026, 10, 17, 11)),
      RouteStop(srNo: 3, name: 'C', time: DateTime(2026, 10, 17, 12)),
    ];
    final mid = placeByClock(stops, DateTime(2026, 10, 17, 11, 30));
    expect(mid.fromIndex, 1);
    expect(mid.toIndex, 2);
    final midRide = rideByClock(stops, DateTime(2026, 10, 17, 11, 30));
    expect(midRide.title, 'On the road');
    expect(midRide.detail, '30 min to C · left B');
    expect(midRide.progress(3), closeTo(0.75, 0.01));
    expect(scheduleNote(stops, DateTime(2026, 10, 17, 9)), 'Not started · Departs 10:00 from A');
    expect(scheduleNote(stops, DateTime(2026, 10, 17, 13)), 'Arrived · C at 12:00');
  });

  test('two GPS samples move a tower stored point', () {
    final table = CellTable();
    const key = CellKey(mcc: 404, mnc: 10, lac: 100, cid: 200);
    table.learn(key, 28, 77);
    expect(table.locate(key)!.lat, 28);
    table.learn(key, 28.2, 77.2);
    final point = table.locate(key)!;
    expect(point.lat, closeTo(28.1, 1e-9));
    expect(point.lng, closeTo(77.1, 1e-9));
  });
}

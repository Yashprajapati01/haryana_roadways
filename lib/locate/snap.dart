import 'dart:math' as math;

import '../timetable/models.dart';

class RouteStop {
  const RouteStop({
    required this.srNo,
    required this.name,
    required this.time,
    this.lat,
    this.lng,
  });

  final int srNo;
  final String name;
  final DateTime time;
  final double? lat;
  final double? lng;

  bool get located => lat != null && lng != null;
}

class SnapHit {
  const SnapHit({
    required this.distanceM,
    required this.crossTrackM,
    required this.fromIndex,
    required this.toIndex,
    required this.fraction,
  });

  final double distanceM;
  final double crossTrackM;
  final int fromIndex;
  final int toIndex;
  final double fraction;
}

class ClockPlace {
  const ClockPlace({
    required this.fromIndex,
    required this.toIndex,
    required this.fraction,
  });

  final int fromIndex;
  final int toIndex;
  final double fraction;
}

const gpsCrossTrackM = 400.0;
const cellCrossTrackM = 2000.0;

double metersBetween(double lat1, double lng1, double lat2, double lng2) {
  const earth = 6371000.0;
  final p1 = lat1 * math.pi / 180;
  final p2 = lat2 * math.pi / 180;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLng = (lng2 - lng1) * math.pi / 180;
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * earth * math.asin(math.min(1, math.sqrt(a)));
}

/// Projects [lat]/[lng] onto the polyline of stops that have coordinates.
/// Returns null when the point is farther than [maxCrossTrackM] from every segment.
SnapHit? snapToRoute(
  List<RouteStop> stops,
  double lat,
  double lng, {
  required double maxCrossTrackM,
}) {
  final located = <int>[
    for (var i = 0; i < stops.length; i++)
      if (stops[i].located) i,
  ];
  if (located.length < 2) return null;

  final along = List<double>.filled(stops.length, 0);
  for (var k = 1; k < located.length; k++) {
    final a = located[k - 1];
    final b = located[k];
    along[b] =
        along[a] +
        metersBetween(stops[a].lat!, stops[a].lng!, stops[b].lat!, stops[b].lng!);
  }

  SnapHit? best;
  for (var k = 1; k < located.length; k++) {
    final ai = located[k - 1];
    final bi = located[k];
    final hit = _project(stops, along, ai, bi, lat, lng);
    if (hit == null) continue;
    if (best == null || hit.crossTrackM < best.crossTrackM) best = hit;
  }
  if (best == null || best.crossTrackM > maxCrossTrackM) return null;
  return best;
}

SnapHit? _project(
  List<RouteStop> stops,
  List<double> along,
  int ai,
  int bi,
  double lat,
  double lng,
) {
  final a = stops[ai];
  final b = stops[bi];
  final ab = _local(a.lat!, a.lng!, b.lat!, b.lng!);
  final ap = _local(a.lat!, a.lng!, lat, lng);
  final len2 = ab.$1 * ab.$1 + ab.$2 * ab.$2;
  if (len2 < 1) return null;
  final t = ((ap.$1 * ab.$1 + ap.$2 * ab.$2) / len2).clamp(0.0, 1.0);
  final cx = ab.$1 * t;
  final cy = ab.$2 * t;
  final cross = math.sqrt((ap.$1 - cx) * (ap.$1 - cx) + (ap.$2 - cy) * (ap.$2 - cy));
  final segment = math.sqrt(len2);
  return SnapHit(
    distanceM: along[ai] + segment * t,
    crossTrackM: cross,
    fromIndex: ai,
    toIndex: bi,
    fraction: t,
  );
}

(double, double) _local(double lat0, double lng0, double lat, double lng) {
  const metersPerDegree = 111320.0;
  final x = (lng - lng0) * metersPerDegree * math.cos(lat0 * math.pi / 180);
  final y = (lat - lat0) * metersPerDegree;
  return (x, y);
}

/// Places a shared distance from the live server back onto this phone's stops.
SnapHit? placeAtDistance(List<RouteStop> stops, double distanceM) {
  final located = <int>[
    for (var i = 0; i < stops.length; i++)
      if (stops[i].located) i,
  ];
  if (located.isEmpty) return null;
  final along = List<double>.filled(stops.length, 0);
  for (var k = 1; k < located.length; k++) {
    final a = located[k - 1];
    final b = located[k];
    along[b] =
        along[a] +
        metersBetween(stops[a].lat!, stops[a].lng!, stops[b].lat!, stops[b].lng!);
  }
  if (located.length == 1 || distanceM <= 0) {
    final i = located.first;
    return SnapHit(
      distanceM: 0,
      crossTrackM: 0,
      fromIndex: i,
      toIndex: i,
      fraction: 0,
    );
  }
  for (var k = 1; k < located.length; k++) {
    final ai = located[k - 1];
    final bi = located[k];
    final span = along[bi] - along[ai];
    if (distanceM > along[bi] && k != located.length - 1) continue;
    final fraction = span <= 1 ? 0.0 : ((distanceM - along[ai]) / span).clamp(0.0, 1.0);
    return SnapHit(
      distanceM: distanceM.clamp(0, along[bi]),
      crossTrackM: 0,
      fromIndex: ai,
      toIndex: bi,
      fraction: fraction,
    );
  }
  final last = located.last;
  return SnapHit(
    distanceM: along[last],
    crossTrackM: 0,
    fromIndex: last,
    toIndex: last,
    fraction: 1,
  );
}

/// Where the timetable says the bus is at [now].
ClockPlace placeByClock(List<RouteStop> stops, DateTime now) {
  if (stops.isEmpty) {
    return const ClockPlace(fromIndex: 0, toIndex: 0, fraction: 0);
  }
  if (!now.isAfter(stops.first.time)) {
    return const ClockPlace(fromIndex: 0, toIndex: 0, fraction: 0);
  }
  final last = stops.length - 1;
  if (!now.isBefore(stops.last.time)) {
    return ClockPlace(fromIndex: last, toIndex: last, fraction: 1);
  }
  for (var i = 0; i < last; i++) {
    final start = stops[i].time;
    final end = stops[i + 1].time;
    if (now.isBefore(start) || !now.isBefore(end)) continue;
    final span = end.difference(start).inSeconds;
    final fraction = span == 0 ? 0.0 : now.difference(start).inSeconds / span;
    return ClockPlace(
      fromIndex: i,
      toIndex: i + 1,
      fraction: fraction.clamp(0.0, 1.0),
    );
  }
  return ClockPlace(fromIndex: last, toIndex: last, fraction: 1);
}

enum RideStatus { notStarted, onRoad, arrived, seen }

/// Fill-in phrases for the place line. English is the default so tests stay stable.
class RideWords {
  const RideWords({
    this.scheduled = 'Scheduled',
    this.notStarted = 'Not started',
    this.onRoad = 'On the road',
    this.arrived = 'Arrived',
    this.seen = 'Seen by riders',
    this.noStops = 'No stops on this duty',
    this.departs = 'Departs {clock} from {name}',
    this.arrivedAt = '{name} at {clock}',
    this.minsTo = '{mins} min to {name}',
    this.dueAt = 'Due at {name}',
    this.leftName = 'left {name}',
    this.atStop = 'At {name}',
    this.leftNext = 'Left {name} · next {next}',
    this.late = '{mins} min late',
    this.early = '{mins} min early',
  });

  final String scheduled;
  final String notStarted;
  final String onRoad;
  final String arrived;
  final String seen;
  final String noStops;
  final String departs;
  final String arrivedAt;
  final String minsTo;
  final String dueAt;
  final String leftName;
  final String atStop;
  final String leftNext;
  final String late;
  final String early;

  String fill(String pattern, Map<String, String> vars) {
    var text = pattern;
    for (final entry in vars.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value);
    }
    return text;
  }
}

class RidePlace {
  const RidePlace({
    required this.status,
    required this.fromIndex,
    required this.toIndex,
    required this.fraction,
    required this.title,
    required this.detail,
  });

  final RideStatus status;
  final int fromIndex;
  final int toIndex;
  final double fraction;
  final String title;
  final String detail;

  /// 0 at the first stop, 1 after the last. [count] is the number of stops.
  double progress(int count) {
    if (count <= 1) return status == RideStatus.arrived ? 1 : 0;
    if (status == RideStatus.arrived) return 1;
    if (status == RideStatus.notStarted) return 0;
    final along = fromIndex + (fromIndex == toIndex ? 0 : fraction);
    return (along / (count - 1)).clamp(0.0, 1.0);
  }
}

RidePlace rideByClock(
  List<RouteStop> stops,
  DateTime now, {
  RideWords words = const RideWords(),
}) {
  if (stops.isEmpty) {
    return RidePlace(
      status: RideStatus.notStarted,
      fromIndex: 0,
      toIndex: 0,
      fraction: 0,
      title: words.scheduled,
      detail: words.noStops,
    );
  }
  final place = placeByClock(stops, now);
  if (place.fromIndex == place.toIndex && !now.isAfter(stops.first.time)) {
    final stop = stops.first;
    return RidePlace(
      status: RideStatus.notStarted,
      fromIndex: 0,
      toIndex: 0,
      fraction: 0,
      title: words.notStarted,
      detail: words.fill(words.departs, {'clock': clockLabel(stop.time), 'name': stop.name}),
    );
  }
  if (place.fromIndex == place.toIndex) {
    final stop = stops[place.fromIndex];
    return RidePlace(
      status: RideStatus.arrived,
      fromIndex: place.fromIndex,
      toIndex: place.toIndex,
      fraction: 1,
      title: words.arrived,
      detail: words.fill(words.arrivedAt, {'name': stop.name, 'clock': clockLabel(stop.time)}),
    );
  }
  final from = stops[place.fromIndex];
  final to = stops[place.toIndex];
  final mins = to.time.difference(now).inMinutes;
  final when = mins <= 0
      ? words.fill(words.dueAt, {'name': to.name})
      : words.fill(words.minsTo, {'mins': '$mins', 'name': to.name});
  final left = words.fill(words.leftName, {'name': from.name});
  return RidePlace(
    status: RideStatus.onRoad,
    fromIndex: place.fromIndex,
    toIndex: place.toIndex,
    fraction: place.fraction,
    title: words.onRoad,
    detail: '$when · $left',
  );
}

/// A shared rider fix. Late or early only while the fix sits between two stops.
RidePlace rideSeen(
  List<RouteStop> stops,
  SnapHit hit,
  DateTime now, {
  RideWords words = const RideWords(),
}) {
  final from = stops[hit.fromIndex];
  final to = stops[hit.toIndex];
  if (hit.fromIndex == hit.toIndex) {
    return RidePlace(
      status: RideStatus.seen,
      fromIndex: hit.fromIndex,
      toIndex: hit.toIndex,
      fraction: hit.fraction,
      title: words.seen,
      detail: words.fill(words.atStop, {'name': from.name}),
    );
  }
  final late = minutesLate(stops, hit, now);
  final drift = late.abs() < 1
      ? ''
      : late > 0
      ? ' · ${words.fill(words.late, {'mins': '$late'})}'
      : ' · ${words.fill(words.early, {'mins': '${-late}'})}';
  return RidePlace(
    status: RideStatus.seen,
    fromIndex: hit.fromIndex,
    toIndex: hit.toIndex,
    fraction: hit.fraction,
    title: words.seen,
    detail: '${words.fill(words.leftNext, {'name': from.name, 'next': to.name})}$drift',
  );
}

String scheduleNote(List<RouteStop> stops, DateTime now) {
  final ride = rideByClock(stops, now);
  return '${ride.title} · ${ride.detail}';
}

int minutesLate(List<RouteStop> stops, SnapHit hit, DateTime now) {
  final start = stops[hit.fromIndex].time;
  final end = stops[hit.toIndex].time;
  final seconds = (end.difference(start).inSeconds * hit.fraction).round();
  final scheduled = start.add(Duration(seconds: seconds));
  return now.difference(scheduled).inMinutes;
}

class Observation {
  const Observation({
    required this.clientId,
    required this.dutyId,
    required this.date,
    required this.distanceM,
    required this.lat,
    required this.lng,
    required this.at,
    required this.confirmed,
  });

  final String clientId;
  final int dutyId;
  final String date;
  final double distanceM;
  final double lat;
  final double lng;
  final DateTime at;
  final bool confirmed;
}

class LiveFix {
  const LiveFix({
    required this.distanceM,
    required this.lat,
    required this.lng,
    required this.agreeing,
  });

  final double distanceM;
  final double lat;
  final double lng;
  final int agreeing;
}

/// Two different phones in the last two minutes, or one confirmed rider
/// with three on-route points in that window.
LiveFix? agree(
  List<Observation> all, {
  required int dutyId,
  required String date,
  required DateTime now,
}) {
  final recent = all.where((obs) {
    return obs.dutyId == dutyId &&
        obs.date == date &&
        now.difference(obs.at) <= const Duration(minutes: 2) &&
        !now.difference(obs.at).isNegative;
  }).toList();
  final byClient = <String, List<Observation>>{};
  for (final obs in recent) {
    byClient.putIfAbsent(obs.clientId, () => []).add(obs);
  }
  if (byClient.length >= 2) {
    final latest = [
      for (final list in byClient.values)
        list.reduce((a, b) => a.at.isAfter(b.at) ? a : b),
    ];
    final distance = _median(latest.map((obs) => obs.distanceM));
    final closest = latest.reduce((a, b) {
      final da = (a.distanceM - distance).abs();
      final db = (b.distanceM - distance).abs();
      return da <= db ? a : b;
    });
    return LiveFix(
      distanceM: distance,
      lat: closest.lat,
      lng: closest.lng,
      agreeing: latest.length,
    );
  }
  if (byClient.length == 1) {
    final list = byClient.values.single;
    if (list.length >= 3 && list.every((obs) => obs.confirmed)) {
      final last = list.reduce((a, b) => a.at.isAfter(b.at) ? a : b);
      return LiveFix(
        distanceM: last.distanceM,
        lat: last.lat,
        lng: last.lng,
        agreeing: 1,
      );
    }
  }
  return null;
}

double _median(Iterable<double> values) {
  final sorted = values.toList()..sort();
  final n = sorted.length;
  if (n.isOdd) return sorted[n ~/ 2];
  return (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
}

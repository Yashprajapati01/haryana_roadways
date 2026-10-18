class CellKey {
  const CellKey({
    required this.mcc,
    required this.mnc,
    required this.lac,
    required this.cid,
  });

  final int mcc;
  final int mnc;
  final int lac;
  final int cid;

  @override
  bool operator ==(Object other) {
    return other is CellKey &&
        other.mcc == mcc &&
        other.mnc == mnc &&
        other.lac == lac &&
        other.cid == cid;
  }

  @override
  int get hashCode => Object.hash(mcc, mnc, lac, cid);
}

class LatLng {
  const LatLng(this.lat, this.lng);

  final double lat;
  final double lng;
}

/// Tower positions learned from GPS fixes on the same cell.
class CellTable {
  CellTable([Map<CellKey, List<LatLng>>? samples])
    : _samples = samples ?? <CellKey, List<LatLng>>{};

  final Map<CellKey, List<LatLng>> _samples;

  void learn(CellKey key, double lat, double lng) {
    final list = _samples.putIfAbsent(key, () => <LatLng>[]);
    list.add(LatLng(lat, lng));
    if (list.length > 21) list.removeAt(0);
  }

  LatLng? locate(CellKey key) {
    final list = _samples[key];
    if (list == null || list.isEmpty) return null;
    return LatLng(_median(list.map((p) => p.lat)), _median(list.map((p) => p.lng)));
  }

  List<LatLng> samplesOf(CellKey key) {
    return List<LatLng>.unmodifiable(_samples[key] ?? const <LatLng>[]);
  }

  static double _median(Iterable<double> values) {
    final sorted = values.toList()..sort();
    final n = sorted.length;
    if (n.isOdd) return sorted[n ~/ 2];
    return (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
  }
}

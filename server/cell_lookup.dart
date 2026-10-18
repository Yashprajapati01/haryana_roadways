class CellPlace {
  const CellPlace({required this.lat, required this.lng, required this.range});

  final double lat;
  final double lng;

  /// Metres. OpenCellID's estimate of how far the point may be from the tower.
  final double range;
}

/// OpenCellID JSON. Missing lat/lon is an unknown cell, not a thrown error.
CellPlace? parseOpenCell(Object? body) {
  if (body is! Map) return null;
  final lat = body['lat'];
  final lon = body['lon'];
  if (lat is! num || lon is! num) return null;
  final range = body['range'];
  return CellPlace(
    lat: lat.toDouble(),
    lng: lon.toDouble(),
    range: range is num && range > 0 ? range.toDouble() : 2000,
  );
}

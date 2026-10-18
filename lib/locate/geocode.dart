import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cell_table.dart';

class Geocoder {
  Geocoder({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// ponytail: the region comes from a token in the stop name (HP, PB, Delhi,
  /// Chandigarh). A name with no token is still queried as Haryana, so a
  /// Punjab stop spelled without PB can land in the wrong place. Upgrade path
  /// is a stop coordinate table.
  Future<LatLng?> lookup(String name) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': geocodeQuery(name),
      'format': 'json',
      'limit': '1',
    });
    final response = await _client.get(
      uri,
      headers: {'User-Agent': 'HaryanaRoadways/1.0'},
    );
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body);
    if (body is! List || body.isEmpty || body.first is! Map) return null;
    final row = body.first as Map;
    final lat = double.tryParse(row['lat']?.toString() ?? '');
    final lng = double.tryParse(row['lon']?.toString() ?? '');
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }
}

/// Region suffix for Nominatim. HP and PB are checked before Delhi so a
/// border name such as "PB/HP" follows the first explicit token.
String geocodeQuery(String name) {
  final upper = name.toUpperCase();
  if (RegExp(r'H\.P|\bHP\b').hasMatch(upper)) {
    return '$name, Himachal Pradesh, India';
  }
  if (RegExp(r'\(PB|\bPB\b|PUNJAB').hasMatch(upper)) {
    return '$name, Punjab, India';
  }
  if (upper.contains('DELHI')) return '$name, Delhi, India';
  if (upper.contains('CHANDIGARH')) return '$name, Chandigarh, India';
  return '$name, Haryana, India';
}

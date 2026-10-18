import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class HrException implements Exception {
  HrException(this.message);
  final String message;

  @override
  String toString() => message;
}

class HrApi {
  HrApi({http.Client? client}) : _client = client ?? http.Client();

  static const _base = 'https://api.hrtransport.org/misInfo';

  // Public client header already shipped in the timetable site's bundle.
  static const _auth = 'Bearer 5FC74043-4CBC-EF11-9194-98F2B32FB60F';

  final http.Client _client;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': _auth,
  };

  Future<List<Station>> stations(String query) async {
    final uri = Uri.parse(
      '$_base/TimetableStationList/${Uri.encodeComponent(query.trim())}',
    );
    final response = await _client.get(uri, headers: _headers);
    return _models(response).map(Station.fromJson).toList();
  }

  Future<List<TripStop>> trips({
    required List<Station> boarding,
    required List<Station> destination,
  }) async {
    final response = await _client.post(
      Uri.parse('$_base/TimetableList'),
      headers: _headers,
      body: jsonEncode({
        'boardingStationList': boarding.map((s) => s.toJson()).toList(),
        'destinationStationList': destination.map((s) => s.toJson()).toList(),
      }),
    );
    final list = _models(response).map(TripStop.fromJson).toList();
    list.sort((a, b) => a.tripTime.compareTo(b.tripTime));
    return list;
  }

  Future<List<TripStop>> dutyStops(int dutyId) async {
    final response = await _client.get(
      Uri.parse('$_base/TimetableStationDetail/$dutyId'),
      headers: _headers,
    );
    final list = _models(response).map(TripStop.fromJson).toList();
    list.sort((a, b) => a.srNo.compareTo(b.srNo));
    return list;
  }

  List<Map<String, dynamic>> _models(http.Response response) {
    if (response.statusCode != 200) {
      throw HrException('Timetable request failed (${response.statusCode})');
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw HrException('Timetable response was not an object');
    }
    if (body['didError'] == true) {
      final message = body['errorMessage']?.toString();
      throw HrException(
        message == null || message.isEmpty ? 'Timetable request failed' : message,
      );
    }
    final model = body['model'];
    if (model is! List) return const [];
    return model.whereType<Map<String, dynamic>>().toList();
  }
}

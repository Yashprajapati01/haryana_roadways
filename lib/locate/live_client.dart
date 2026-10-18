import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cell_table.dart';

class TowerPlace {
  const TowerPlace({required this.lat, required this.lng, required this.range});

  final double lat;
  final double lng;
  final double range;
}

class SeenFix {
  const SeenFix({
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

class LiveLook {
  const LiveLook({required this.reached, this.fix});

  final bool reached;
  final SeenFix? fix;
}

class LiveClient {
  LiveClient({http.Client? client, String? base})
    : _client = client ?? http.Client(),
      base = base ??
          const String.fromEnvironment(
            'LIVE_BASE',
            defaultValue: 'https://haryana-roadways.onrender.com',
          );

  final http.Client _client;
  final String base;

  Future<void> upload({
    required String clientId,
    required int dutyId,
    required String date,
    required double distanceM,
    required double lat,
    required double lng,
    required String source,
    required bool confirmed,
  }) async {
    try {
      await _client
          .post(
            Uri.parse('$base/observations'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'clientId': clientId,
              'dutyId': dutyId,
              'date': date,
              'distanceM': distanceM,
              'lat': lat,
              'lng': lng,
              'source': source,
              'confirmed': confirmed,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<SeenFix?> position(int dutyId, String date) async {
    final look = await this.look(dutyId, date);
    return look.fix;
  }

  /// Approximate place for a tower. Null when this cell is unknown or the lookup failed.
  Future<TowerPlace?> tower(CellKey key, {String radio = ''}) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$base/cells').replace(
              queryParameters: {
                'mcc': '${key.mcc}',
                'mnc': '${key.mnc}',
                'lac': '${key.lac}',
                'cid': '${key.cid}',
                if (radio.isNotEmpty) 'radio': radio,
              },
            ),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! Map || body['status'] != 'seen') return null;
      return TowerPlace(
        lat: (body['lat'] as num).toDouble(),
        lng: (body['lng'] as num).toDouble(),
        range: (body['range'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  /// [reached] is false when this phone cannot ask the live server.
  /// A reached look with a null fix means nobody has agreed on this duty.
  Future<LiveLook> look(
    int dutyId,
    String date, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final response = await _client
          .get(Uri.parse('$base/duties/$dutyId/position?date=$date'))
          .timeout(timeout);
      if (response.statusCode != 200) return const LiveLook(reached: false);
      final body = jsonDecode(response.body);
      if (body is! Map) return const LiveLook(reached: false);
      if (body['status'] != 'seen') return const LiveLook(reached: true);
      return LiveLook(
        reached: true,
        fix: SeenFix(
          distanceM: (body['distanceM'] as num).toDouble(),
          lat: (body['lat'] as num).toDouble(),
          lng: (body['lng'] as num).toDouble(),
          agreeing: (body['agreeing'] as num).toInt(),
        ),
      );
    } catch (_) {
      return const LiveLook(reached: false);
    }
  }
}

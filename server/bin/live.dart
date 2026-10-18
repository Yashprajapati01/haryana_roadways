import 'dart:convert';
import 'dart:io';

import '../cell_lookup.dart';
import '../live_rule.dart';

/// In-memory live bus positions. Restart clears them.
/// ponytail: one process, no disk. Upgrade path is a sqlite file if a restart
/// must keep the last few minutes of rider points.
Future<void> main() async {
  final observations = <Observation>[];
  final towers = <String, CellPlace?>{};
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8787;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('live bus server on http://${server.address.address}:$port');
  await for (final request in server) {
    _cors(request.response);
    if (request.method == 'OPTIONS') {
      request.response.statusCode = 204;
      await request.response.close();
      continue;
    }
    final now = DateTime.now();
    observations.removeWhere((obs) => now.difference(obs.at) > const Duration(minutes: 15));
    try {
      if (request.method == 'POST' && request.uri.path == '/observations') {
        await _post(request, observations, now);
      } else if (request.method == 'GET' && request.uri.path == '/cells') {
        await _cell(request, towers);
      } else if (request.method == 'GET' &&
          (request.uri.path == '/' || request.uri.path == '/health')) {
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"ok":true}');
      } else if (request.method == 'GET' && request.uri.pathSegments.length == 3) {
        await _get(request, observations, now);
      } else {
        request.response.statusCode = 404;
        request.response.write('not found');
      }
    } catch (_) {
      request.response.statusCode = 400;
      request.response.write('bad request');
    }
    await request.response.close();
  }
}

void _cors(HttpResponse response) {
  response.headers
    ..set('Access-Control-Allow-Origin', '*')
    ..set('Access-Control-Allow-Headers', 'Content-Type')
    ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
}

Future<void> _post(HttpRequest request, List<Observation> observations, DateTime now) async {
  final raw = await utf8.decoder.bind(request).join();
  final body = jsonDecode(raw);
  if (body is! Map) throw StateError('body');
  observations.add(
    Observation(
      clientId: body['clientId'].toString(),
      dutyId: (body['dutyId'] as num).toInt(),
      date: body['date'].toString(),
      distanceM: (body['distanceM'] as num).toDouble(),
      lat: (body['lat'] as num).toDouble(),
      lng: (body['lng'] as num).toDouble(),
      at: now,
      confirmed: body['confirmed'] == true,
    ),
  );
  request.response.statusCode = 204;
}

Future<void> _cell(HttpRequest request, Map<String, CellPlace?> towers) async {
  final query = request.uri.queryParameters;
  final mcc = int.tryParse(query['mcc'] ?? '');
  final mnc = int.tryParse(query['mnc'] ?? '');
  final lac = int.tryParse(query['lac'] ?? '');
  final cid = int.tryParse(query['cid'] ?? '');
  final radio = query['radio'] ?? '';
  if (mcc == null || mnc == null || lac == null || cid == null) {
    request.response.statusCode = 400;
    request.response.write('bad cell');
    return;
  }
  final apiKey = Platform.environment['OPENCELLID_KEY'] ?? '';
  request.response.headers.contentType = ContentType.json;
  if (apiKey.isEmpty) {
    request.response.statusCode = 503;
    request.response.write(jsonEncode({'status': 'unconfigured'}));
    return;
  }
  final id = '$mcc:$mnc:$lac:$cid:$radio';
  CellPlace? place;
  if (towers.containsKey(id)) {
    place = towers[id];
  } else {
    try {
      place = await _openCell(apiKey, mcc: mcc, mnc: mnc, lac: lac, cid: cid, radio: radio);
      towers[id] = place;
    } catch (_) {
      place = null;
    }
  }
  if (place == null) {
    request.response.write(jsonEncode({'status': 'none'}));
    return;
  }
  request.response.write(
    jsonEncode({'status': 'seen', 'lat': place.lat, 'lng': place.lng, 'range': place.range}),
  );
}

Future<CellPlace?> _openCell(
  String apiKey, {
  required int mcc,
  required int mnc,
  required int lac,
  required int cid,
  required String radio,
}) async {
  final uri = Uri.https('opencellid.org', '/cell/get', {
    'key': apiKey,
    'mcc': '$mcc',
    'mnc': '$mnc',
    'lac': '$lac',
    'cellid': '$cid',
    if (radio == 'GSM' || radio == 'UMTS' || radio == 'LTE' || radio == 'NR') 'radio': radio,
    'format': 'json',
  });
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close().timeout(const Duration(seconds: 8));
    final raw = await utf8.decoder.bind(response).join();
    if (response.statusCode != 200) throw StateError('upstream');
    return parseOpenCell(jsonDecode(raw));
  } finally {
    client.close();
  }
}

Future<void> _get(HttpRequest request, List<Observation> observations, DateTime now) async {
  final parts = request.uri.pathSegments;
  if (parts[0] != 'duties' || parts[2] != 'position') {
    request.response.statusCode = 404;
    return;
  }
  final dutyId = int.parse(parts[1]);
  final date = request.uri.queryParameters['date'] ?? '';
  final fix = agree(observations, dutyId: dutyId, date: date, now: now);
  request.response.headers.contentType = ContentType.json;
  if (fix == null) {
    request.response.write(jsonEncode({'status': 'none'}));
    return;
  }
  request.response.write(
    jsonEncode({
      'status': 'seen',
      'distanceM': fix.distanceM,
      'lat': fix.lat,
      'lng': fix.lng,
      'agreeing': fix.agreeing,
    }),
  );
}

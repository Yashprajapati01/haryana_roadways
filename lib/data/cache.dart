import 'dart:convert';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../locate/cell_table.dart';
import '../locate/snap.dart';
import '../timetable/models.dart';

class RecentPair {
  const RecentPair({
    required this.fromId,
    required this.fromName,
    required this.toId,
    required this.toName,
  });

  final int fromId;
  final String fromName;
  final int toId;
  final String toName;

  Station get from => Station(stationID: fromId, stationName: fromName);

  Station get to => Station(stationID: toId, stationName: toName);
}

class GeoRow {
  const GeoRow({this.lat, this.lng, required this.missed});

  final double? lat;
  final double? lng;
  final bool missed;
}

class AppCache {
  AppCache(this._db);

  final Database _db;

  static Future<AppCache> open() async {
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, 'haryana_roadways.db'),
      version: 2,
      onCreate: (db, version) async {
        await _schema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS duties (duty_id INTEGER NOT NULL, day TEXT NOT NULL, stops TEXT NOT NULL, PRIMARY KEY (duty_id, day))',
          );
          await db.execute(
            'CREATE TABLE IF NOT EXISTS recent (from_id INTEGER NOT NULL, from_name TEXT NOT NULL, to_id INTEGER NOT NULL, to_name TEXT NOT NULL, at INTEGER NOT NULL, PRIMARY KEY (from_id, to_id))',
          );
        }
      },
    );
    return AppCache(db);
  }

  static Future<void> _schema(Database db) async {
    await db.execute(
      'CREATE TABLE geo (name TEXT PRIMARY KEY, lat REAL, lng REAL, missed INTEGER NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE towers (mcc INTEGER, mnc INTEGER, lac INTEGER, cid INTEGER, samples TEXT NOT NULL, PRIMARY KEY (mcc, mnc, lac, cid))',
    );
    await db.execute('CREATE TABLE meta (k TEXT PRIMARY KEY, v TEXT NOT NULL)');
    await db.execute(
      'CREATE TABLE duties (duty_id INTEGER NOT NULL, day TEXT NOT NULL, stops TEXT NOT NULL, PRIMARY KEY (duty_id, day))',
    );
    await db.execute(
      'CREATE TABLE recent (from_id INTEGER NOT NULL, from_name TEXT NOT NULL, to_id INTEGER NOT NULL, to_name TEXT NOT NULL, at INTEGER NOT NULL, PRIMARY KEY (from_id, to_id))',
    );
  }

  Future<GeoRow?> geo(String name) async {
    final rows = await _db.query('geo', where: 'name = ?', whereArgs: [name]);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return GeoRow(
      lat: row['lat'] as double?,
      lng: row['lng'] as double?,
      missed: row['missed'] == 1,
    );
  }

  Future<void> saveGeo(String name, {double? lat, double? lng, bool missed = false}) {
    return _db.insert('geo', {
      'name': name,
      'lat': lat,
      'lng': lng,
      'missed': missed ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<LatLng>> towerSamples(CellKey key) async {
    final rows = await _db.query(
      'towers',
      where: 'mcc = ? AND mnc = ? AND lac = ? AND cid = ?',
      whereArgs: [key.mcc, key.mnc, key.lac, key.cid],
    );
    if (rows.isEmpty) return const [];
    final raw = jsonDecode(rows.first['samples']! as String);
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is List && item.length >= 2)
          LatLng((item[0] as num).toDouble(), (item[1] as num).toDouble()),
    ];
  }

  Future<void> saveTower(CellKey key, List<LatLng> samples) {
    return _db.insert('towers', {
      'mcc': key.mcc,
      'mnc': key.mnc,
      'lac': key.lac,
      'cid': key.cid,
      'samples': jsonEncode([
        for (final sample in samples) [sample.lat, sample.lng],
      ]),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<RouteStop>?> duty(int dutyId, String day) async {
    final rows = await _db.query(
      'duties',
      where: 'duty_id = ? AND day = ?',
      whereArgs: [dutyId, day],
    );
    if (rows.isEmpty) return null;
    final raw = jsonDecode(rows.first['stops']! as String);
    if (raw is! List) return null;
    return [
      for (final item in raw)
        if (item is Map)
          RouteStop(
            srNo: (item['sr'] as num?)?.toInt() ?? 0,
            name: item['name']?.toString() ?? '',
            time: DateTime.parse(item['time'].toString()),
          ),
    ];
  }

  Future<void> saveDuty(int dutyId, String day, List<RouteStop> stops) {
    return _db.insert('duties', {
      'duty_id': dutyId,
      'day': day,
      'stops': jsonEncode([
        for (final stop in stops)
          {'sr': stop.srNo, 'name': stop.name, 'time': stop.time.toIso8601String()},
      ]),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<RecentPair>> recents() async {
    final rows = await _db.query('recent', orderBy: 'at DESC', limit: 6);
    return [
      for (final row in rows)
        RecentPair(
          fromId: row['from_id']! as int,
          fromName: row['from_name']! as String,
          toId: row['to_id']! as int,
          toName: row['to_name']! as String,
        ),
    ];
  }

  Future<void> remember(Station from, Station to) async {
    await _db.insert('recent', {
      'from_id': from.stationID,
      'from_name': from.stationName,
      'to_id': to.stationID,
      'to_name': to.stationName,
      'at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final rows = await _db.query('recent', orderBy: 'at DESC');
    for (final extra in rows.skip(6)) {
      await _db.delete(
        'recent',
        where: 'from_id = ? AND to_id = ?',
        whereArgs: [extra['from_id'], extra['to_id']],
      );
    }
  }

  Future<String> clientId() async {
    final rows = await _db.query('meta', where: 'k = ?', whereArgs: ['client']);
    if (rows.isNotEmpty) return rows.first['v']! as String;
    final id = _randomId();
    await _db.insert('meta', {'k': 'client', 'v': id});
    return id;
  }

  String _randomId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

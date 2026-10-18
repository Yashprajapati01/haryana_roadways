import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import 'cell_table.dart';

class CellReader {
  static const _channel = MethodChannel('haryana_roadways/cell');

  Future<void> prepare() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('prepareTracking');
    } catch (_) {}
  }

  /// System location dialog. True when fine location is allowed.
  Future<bool> requestLocation() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final ok = await _channel.invokeMethod<bool>('requestLocation');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestNotifications() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('requestNotifications');
    } catch (_) {}
  }

  Future<CellKey?> serving() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final raw = await _channel.invokeMapMethod<Object?, Object?>('servingCell');
      if (raw == null) return null;
      final mcc = _asInt(raw['mcc']);
      final mnc = _asInt(raw['mnc']);
      final lac = _asInt(raw['lac']);
      final cid = _asInt(raw['cid']);
      if (mcc == null || mnc == null || lac == null || cid == null) return null;
      if (mcc <= 0 || mnc < 0 || lac < 0 || cid < 0) return null;
      return CellKey(mcc: mcc, mnc: mnc, lac: lac, cid: cid);
    } catch (_) {
      return null;
    }
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}

enum RideBlock { off, denied, failed }

class RideBlocked implements Exception {
  const RideBlocked(this.block);

  final RideBlock block;
}

class OnBusTracker {
  StreamSubscription<Position>? _sub;

  /// Asks the system for location. The GPS stream stays off until [start].
  Future<void> permit(CellReader cells) async {
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      throw const RideBlocked(RideBlock.off);
    }
    if (!kIsWeb && Platform.isAndroid) {
      final ok = await cells.requestLocation();
      if (ok) return;
      final status = await Geolocator.checkPermission();
      if (status == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
      }
      throw const RideBlocked(RideBlock.denied);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const RideBlocked(RideBlock.denied);
    }
  }

  Future<void> start(
    void Function(Position position) onPosition, {
    required String noticeTitle,
    required String noticeText,
    required CellReader cells,
  }) async {
    await permit(cells);
    await cells.requestNotifications();
    await _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: _settings(noticeTitle, noticeText),
    ).listen(onPosition);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  LocationSettings _settings(String noticeTitle, String noticeText) {
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 40,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: noticeTitle,
          notificationText: noticeText,
          setOngoing: true,
        ),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 40,
    );
  }
}

class Station {
  const Station({required this.stationID, required this.stationName});

  final int stationID;
  final String stationName;

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      stationID: _asInt(json['stationID']) ?? 0,
      stationName: json['stationName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'stationID': stationID,
    'stationName': stationName,
  };
}

class TripStop {
  const TripStop({
    required this.dutyID,
    required this.routationID,
    required this.tripID,
    required this.boardingStationID,
    required this.destinationStationID,
    required this.srNo,
    required this.tripTime,
    required this.direction,
    required this.routationSrNo,
    required this.boardingStationName,
    required this.destinationStationName,
    required this.tripName,
    required this.vehicleNumber,
    required this.vehicleType1,
    required this.depotID,
    required this.depotName,
    required this.dt,
  });

  final int dutyID;
  final int routationID;
  final int tripID;
  final int boardingStationID;
  final int destinationStationID;
  final int srNo;
  final DateTime tripTime;
  final String direction;
  final int routationSrNo;
  final String boardingStationName;
  final String destinationStationName;
  final String tripName;
  final String? vehicleNumber;
  final String? vehicleType1;
  final int depotID;
  final String depotName;
  final DateTime? dt;

  /// On a duty's stop list both name fields are the stop itself.
  String get stopName {
    final name = boardingStationName.trim();
    if (name.isNotEmpty) return name;
    return destinationStationName.trim();
  }

  factory TripStop.fromJson(Map<String, dynamic> json) {
    return TripStop(
      dutyID: _asInt(json['dutyID']) ?? 0,
      routationID: _asInt(json['routationID']) ?? 0,
      tripID: _asInt(json['tripID']) ?? 0,
      boardingStationID: _asInt(json['boardingStationID']) ?? 0,
      destinationStationID: _asInt(json['destinationStationID']) ?? 0,
      srNo: _asInt(json['srNo']) ?? 0,
      tripTime: DateTime.parse(json['tripTime'].toString()),
      direction: json['direction']?.toString() ?? '',
      routationSrNo: _asInt(json['routationSrNo']) ?? 0,
      boardingStationName: json['boardingStationName']?.toString() ?? '',
      destinationStationName: json['destinationStationName']?.toString() ?? '',
      tripName: json['tripName']?.toString() ?? '',
      vehicleNumber: _blankToNull(json['vehicleNumber']),
      vehicleType1: _blankToNull(json['vehicleType1']),
      depotID: _asInt(json['depotID']) ?? 0,
      depotName: json['depotName']?.toString() ?? '',
      dt: json['dt'] == null ? null : DateTime.tryParse(json['dt'].toString()),
    );
  }
}

String dayKey(DateTime time) {
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  return '${time.year}-$month-$day';
}

String clockLabel(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? _blankToNull(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty || text == 'null') return null;
  return text;
}

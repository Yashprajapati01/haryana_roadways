import 'package:flutter_test/flutter_test.dart';
import '../server/cell_lookup.dart';

void main() {
  test('a cell lookup with coordinates is a place', () {
    final place = parseOpenCell({
      'lat': 29.39,
      'lon': 76.97,
      'range': 1200,
    });
    expect(place?.lat, 29.39);
    expect(place?.lng, 76.97);
    expect(place?.range, 1200);
  });

  test('a cell lookup without coordinates is unknown', () {
    expect(parseOpenCell({'error': 'Cell not found'}), isNull);
    expect(parseOpenCell('nope'), isNull);
  });
}
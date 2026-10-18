import 'package:flutter_test/flutter_test.dart';
import 'package:haryana_roadways/locate/geocode.dart';

void main() {
  test('stop names keep the region written on them', () {
    expect(geocodeQuery('DHARMSALA ISBT HP'), 'DHARMSALA ISBT HP, Himachal Pradesh, India');
    expect(geocodeQuery('SHAKOH (H.P)'), 'SHAKOH (H.P), Himachal Pradesh, India');
    expect(geocodeQuery('KIRATPUR (PB)'), 'KIRATPUR (PB), Punjab, India');
    expect(geocodeQuery('DELHI'), 'DELHI, Delhi, India');
    expect(geocodeQuery('CHANDIGARH'), 'CHANDIGARH, Chandigarh, India');
    expect(geocodeQuery('KARNAL'), 'KARNAL, Haryana, India');
  });
}

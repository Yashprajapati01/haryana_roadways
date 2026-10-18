import 'package:flutter_test/flutter_test.dart';
import 'package:haryana_roadways/main.dart';
import 'package:haryana_roadways/ui/copy.dart';

void main() {
  test('hindi changes labels and known cities', () {
    const hi = Copy.hindi();
    expect(hi.from, 'कहाँ से');
    expect(hi.place('JAIPUR'), 'जयपुर');
    expect(hi.place('ISBT CHANDIGARH'), 'आईएसबीटी चंडीगढ़');
    expect(hi.place('HR69GV7194 (Ordinary)'), 'HR69GV7194 (साधारण)');
    expect(hi.place('Kaithal'), 'कैथल');
    expect(hi.place('SONEPAT'), 'सोनीपत');
    expect(const Copy.english().place('JAIPUR'), 'JAIPUR');
    expect(const Copy.english().searchBuses, 'Search buses');
  });

  testWidgets('search page asks for the two stations', (tester) async {
    await tester.pumpWidget(const HaryanaApp());
    expect(find.text('From'), findsOneWidget);
    expect(find.text('To'), findsOneWidget);
    expect(find.text('Search buses'), findsOneWidget);
  });
}

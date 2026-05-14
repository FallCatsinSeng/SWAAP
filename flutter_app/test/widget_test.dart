import 'package:flutter_test/flutter_test.dart';

import 'package:legacy_wrapper_fe/main.dart';

void main() {
  testWidgets('Login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const SwaapApp());
    expect(find.text('SWAAP'), findsOneWidget);
    expect(find.text('Login Akademik'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}

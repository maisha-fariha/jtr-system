import 'package:flutter_test/flutter_test.dart';

import 'package:jtr_system/main.dart';

void main() {
  testWidgets('Home page smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const JtrSystemApp());
    await tester.pumpAndSettle();

    expect(find.text('JTR System'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Exit'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:jtr_system/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const JtrApp());
    expect(find.byType(JtrApp), findsOneWidget);
  });
}

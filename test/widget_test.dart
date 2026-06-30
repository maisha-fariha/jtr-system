import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:jtr_system/controllers/theme_controller.dart';
import 'package:jtr_system/main.dart';

void main() {
  testWidgets('Home page smoke test', (WidgetTester tester) async {
    Get.put(ThemeController());
    await tester.pumpWidget(const JtrSystemApp());
    await tester.pumpAndSettle();

    expect(find.text('JTR System'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Exit'), findsOneWidget);

    await Get.deleteAll(force: true);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gems/main.dart';

void main() {
  testWidgets('FlutterGemsApp renders welcome message', (WidgetTester tester) async {
    await tester.pumpWidget(const FlutterGemsApp());

    expect(find.text('Welcome to Flutter Gems'), findsOneWidget);
    expect(find.text('Your Flutter project is ready!'), findsOneWidget);
  });
}

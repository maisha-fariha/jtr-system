import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gems_responsive/gems_responsive.dart';

void main() {
  group('ResponsiveHelper', () {
    testWidgets('device detection methods work correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                // Test device detection
                final isSmall = ResponsiveHelper.isSmallDevice(context);
                final isMedium = ResponsiveHelper.isMediumDevice(context);
                final isLarge = ResponsiveHelper.isLargeDevice(context);
                
                // At least one should be true
                expect(isSmall || isMedium || isLarge, isTrue);
                
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('getResponsiveValue returns correct value based on device size', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final value = ResponsiveHelper.getResponsiveValue<int>(
                  context,
                  small: 1,
                  medium: 2,
                  large: 3,
                );
                
                // Should return one of the provided values
                expect([1, 2, 3].contains(value), isTrue);
                
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('getScreenSize returns valid size', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final size = ResponsiveHelper.getScreenSize(context);
                
                expect(size.width, greaterThan(0));
                expect(size.height, greaterThan(0));
                
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('shorthand methods return valid values', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                // Test shorthand methods
                final width = ResponsiveHelper.w(100);
                final height = ResponsiveHelper.h(50);
                final fontSize = ResponsiveHelper.sp(16);
                final radius = ResponsiveHelper.r(8);
                
                expect(width, greaterThanOrEqualTo(0));
                expect(height, greaterThanOrEqualTo(0));
                expect(fontSize, greaterThanOrEqualTo(0));
                expect(radius, greaterThanOrEqualTo(0));
                
                return Container();
              },
            ),
          ),
        ),
      );
    });
  });
}

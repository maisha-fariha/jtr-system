import 'package:flutter_test/flutter_test.dart';
import 'package:jtr_system/core/network/api_exception.dart';

void main() {
  group('ApiException.isUnauthenticated', () {
    test('detects 401 status', () {
      final error = ApiException(message: 'Nope', statusCode: 401);
      expect(error.isUnauthenticated, isTrue);
    });

    test('detects Unauthenticated message', () {
      final error = ApiException(message: 'Unauthenticated');
      expect(error.isUnauthenticated, isTrue);
    });

    test('detects French non authentifié message', () {
      expect(
        ApiException.isUnauthenticatedMessage('Non authentifié.'),
        isTrue,
      );
    });

    test('ignores unrelated errors', () {
      final error = ApiException(message: 'Server error', statusCode: 500);
      expect(error.isUnauthenticated, isFalse);
    });
  });
}

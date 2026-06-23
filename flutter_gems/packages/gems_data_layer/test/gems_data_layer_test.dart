import 'package:flutter_test/flutter_test.dart';
import 'package:gems_data_layer/gems_data_layer.dart';

void main() {
  group('ApiResponse', () {
    test('success response creates correct response', () {
      final response = ApiResponse.success('test data', message: 'Success');
      
      expect(response.success, isTrue);
      expect(response.data, equals('test data'));
      expect(response.message, equals('Success'));
    });

    test('error response creates correct response', () {
      final response = ApiResponse.error('Error occurred', statusCode: 404);
      
      expect(response.success, isFalse);
      expect(response.data, isNull);
      expect(response.message, equals('Error occurred'));
      expect(response.statusCode, equals(404));
    });
  });

  group('ApiConfig', () {
    test('creates config with default values', () {
      const config = ApiConfig(baseUrl: 'https://api.example.com');
      
      expect(config.baseUrl, equals('https://api.example.com'));
      expect(config.defaultHeaders, isEmpty);
      expect(config.timeout, equals(const Duration(seconds: 30)));
      expect(config.enableLogging, isFalse);
    });

    test('copyWith creates new config with updated values', () {
      const config = ApiConfig(baseUrl: 'https://api.example.com');
      final newConfig = config.copyWith(enableLogging: true);
      
      expect(newConfig.baseUrl, equals('https://api.example.com'));
      expect(newConfig.enableLogging, isTrue);
    });
  });
}

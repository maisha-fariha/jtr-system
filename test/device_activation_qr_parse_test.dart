import 'package:flutter_test/flutter_test.dart';
import 'package:jtr_system/data/mappers/device_activation_mapper.dart';

void main() {
  group('DeviceActivationMapper.parseQrText', () {
    test('parses jtrpos:// deep-link QR', () {
      const raw =
          'jtrpos://activate?v=1&api_base_url=192.168.100.116%2Fapi'
          '&code=JTR-C5CF-6860&type=mobile&tenant_schema=mocca';

      final payload = DeviceActivationMapper.parseQrText(raw);

      expect(payload.code, 'JTR-C5CF-6860');
      expect(payload.tenantSchema, 'mocca');
      expect(payload.type, 'mobile');
      expect(payload.version, 1);
      expect(payload.apiBaseUrl, 'http://192.168.100.116/api');
      expect(payload.isMobile, isTrue);
    });

    test('parses JSON QR payload', () {
      const raw = '''
{
  "v": 1,
  "api_base_url": "http://192.168.1.42/api",
  "code": "JTR-A1B2-C3D4",
  "type": "mobile",
  "tenant_schema": "mocca"
}
''';

      final payload = DeviceActivationMapper.parseQrText(raw);

      expect(payload.code, 'JTR-A1B2-C3D4');
      expect(payload.tenantSchema, 'mocca');
      expect(payload.apiBaseUrl, 'http://192.168.1.42/api');
    });

    test('does not treat jtrpos deep link as mock GET URL', () {
      const raw =
          'jtrpos://activate?v=1&api_base_url=192.168.100.116%2Fapi'
          '&code=JTR-C5CF-6860&type=mobile&tenant_schema=mocca';

      expect(DeviceActivationMapper.activationUrlFromQrText(raw), isNull);
      expect(DeviceActivationMapper.isStructuredActivationQr(raw), isTrue);
    });

    test('does not treat full JSON as mock GET URL', () {
      const raw = '''
{
  "v": 1,
  "api_base_url": "http://192.168.1.42/api",
  "code": "JTR-A1B2-C3D4",
  "type": "mobile",
  "tenant_schema": "mocca",
  "url": "https://mocki.io/v1/activate"
}
''';

      expect(DeviceActivationMapper.activationUrlFromQrText(raw), isNull);
      expect(DeviceActivationMapper.isStructuredActivationQr(raw), isTrue);
    });

    test('parses POS base URL QR with form fallbacks', () {
      final payload = DeviceActivationMapper.tryParsePosBaseQrWithFallbacks(
        'http://192.168.1.42/api',
        fallbackCode: 'JTR-A1B2-C3D4',
        fallbackTenantSchema: 'mocca',
      );

      expect(payload, isNotNull);
      expect(payload!.apiBaseUrl, 'http://192.168.1.42/api');
      expect(payload.code, 'JTR-A1B2-C3D4');
      expect(payload.tenantSchema, 'mocca');
    });
  });

  group('DeviceActivationMapper.tryActivationQrPayloadFromResponse', () {
    test('detects bare QR payload from mock GET URL', () {
      final payload = DeviceActivationMapper.tryActivationQrPayloadFromResponse(
        {
          'v': 1,
          'api_base_url': 'http://127.0.0.1:8080/api',
          'code': 'JTR-A1B2-C3D4',
          'type': 'mobile',
          'tenant_schema': 'mocca',
        },
      );

      expect(payload, isNotNull);
      expect(payload!.apiBaseUrl, 'http://127.0.0.1:8080/api');
      expect(payload.code, 'JTR-A1B2-C3D4');
    });

    test('ignores full activate envelope with device_token', () {
      final payload = DeviceActivationMapper.tryActivationQrPayloadFromResponse(
        {
          'success': true,
          'data': {
            'device_id': 7,
            'device_token': 'tok',
            'tenant_schema': 'mocca',
            'api_base_url': 'http://192.168.1.42/api',
          },
        },
      );

      expect(payload, isNull);
    });
  });

  group('DeviceActivationMapper.activationFromJson', () {
    test('uses fallbacks when bypass response omits tenant / api url', () {
      final result = DeviceActivationMapper.activationFromJson(
        {
          'device_id': 42,
          'device_token': 'tok-bypass',
        },
        fallbackTenantSchema: 'mocca',
        fallbackApiBaseUrl: 'https://api.goatech.ma/',
      );

      expect(result.deviceId, '42');
      expect(result.deviceToken, 'tok-bypass');
      expect(result.tenantSchema, 'mocca');
      expect(result.apiBaseUrl, 'https://api.goatech.ma/api');
    });

    test('uses form tenant when mock GET envelope omits tenant_schema', () {
      final result = DeviceActivationMapper.activationFromJson(
        {
          'device_id': 7,
          'device_token': 'mobile_device_token_xyz',
          'tenant_schema': '',
          'api_base_url': 'http://192.168.0.100:8080',
        },
        message: 'Device activated',
        fallbackTenantSchema: 'mocca',
      );

      expect(result.tenantSchema, 'mocca');
      expect(result.apiBaseUrl, 'http://192.168.0.100:8080/api');
      expect(result.message, 'Device activated');
    });
  });
}

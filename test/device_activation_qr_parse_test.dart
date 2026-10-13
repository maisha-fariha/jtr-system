import 'package:flutter_test/flutter_test.dart';
import 'package:jtr_system/core/app_flavor.dart';
import 'package:jtr_system/data/mappers/device_activation_mapper.dart';
import 'package:jtr_system/data/models/device_activation_models.dart';

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
      expect(payload.matchesAppType, isTrue);
    });

    test('rapport flavor accepts mobile_rapport and rejects mobile', () {
      AppFlavorConfig.bootstrap(AppFlavor.rapport);
      addTearDown(() => AppFlavorConfig.bootstrap(AppFlavor.pos));

      final payload = DeviceActivationMapper.parseQrText(
        'jtrpos://activate?v=1&api_base_url=192.168.100.116%2Fapi'
        '&code=JTR-C5CF-6860&type=mobile_rapport&tenant_schema=mocca',
      );
      expect(payload.type, 'mobile_rapport');
      expect(payload.matchesAppType, isTrue);

      expect(
        () => DeviceActivationMapper.parseQrText(
          'jtrpos://activate?v=1&api_base_url=192.168.100.116%2Fapi'
          '&code=JTR-C5CF-6860&type=mobile&tenant_schema=mocca',
        ),
        throwsFormatException,
      );
    });

    test('pos flavor rejects mobile_rapport QR', () {
      expect(
        () => DeviceActivationMapper.parseQrText(
          'jtrpos://activate?v=1&api_base_url=192.168.100.116%2Fapi'
          '&code=JTR-C5CF-6860&type=mobile_rapport&tenant_schema=mocca',
        ),
        throwsFormatException,
      );
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

  group('DeviceActivationMapper.resolveStoredPosApiBaseUrl', () {
    test('stores contacted URL when origins match with port', () {
      final stored = DeviceActivationMapper.resolveStoredPosApiBaseUrl(
        contactedApiBaseUrl: 'http://192.168.0.100:8080',
        responseApiBaseUrl: 'http://192.168.0.100:8080/api',
      );
      expect(stored, 'http://192.168.0.100:8080/api');
    });

    test('throws when response omits port user typed', () {
      expect(
        () => DeviceActivationMapper.resolveStoredPosApiBaseUrl(
          contactedApiBaseUrl: '192.168.0.100:8080',
          responseApiBaseUrl: 'http://192.168.0.100/api',
        ),
        throwsFormatException,
      );
    });

    test('throws when user omits port but server expects custom port', () {
      expect(
        () => DeviceActivationMapper.resolveStoredPosApiBaseUrl(
          contactedApiBaseUrl: '192.168.0.100',
          responseApiBaseUrl: 'http://192.168.0.100:8080',
        ),
        throwsFormatException,
      );
    });

    test('keeps LAN contacted URL when response is localhost', () {
      final stored = DeviceActivationMapper.resolveStoredPosApiBaseUrl(
        contactedApiBaseUrl: 'http://192.168.0.100:8080',
        responseApiBaseUrl: 'http://127.0.0.1/api',
      );
      expect(stored, 'http://192.168.0.100:8080/api');
    });
  });

  group('DeviceActivationMapper session errors', () {
    test('appareil mobile changé requires a new activation', () {
      expect(
        DeviceActivationMapper.mapSessionErrorMessage('Appareil mobile changé'),
        DeviceGateOutcome.needsActivation,
      );
      expect(
        DeviceActivationMapper.isDeviceBindingFailure('Appareil mobile changé'),
        isTrue,
      );
    });

    test('deactivated keeps credentials (blocked screen)', () {
      expect(
        DeviceActivationMapper.mapSessionErrorMessage('Device deactivated'),
        DeviceGateOutcome.deactivated,
      );
    });

    test('bare token revoked on other endpoints is not a device failure', () {
      expect(
        DeviceActivationMapper.isDeviceBindingFailure('Token revoked'),
        isFalse,
      );
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

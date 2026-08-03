import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../models/api_envelope.dart';
import '../models/realtime/pos_bootstrap_config.dart';

class RealtimeRemoteDataSource {
  RealtimeRemoteDataSource(this._client);

  final ApiClient _client;

  /// `GET /api/pos/bootstrap` — no auth / no device headers (mobile guide).
  Future<PosBootstrapConfig> fetchBootstrap() async {
    try {
      final response = await _client.get<dynamic>(
        ApiEndpoints.posBootstrap,
        options: Options(
          extra: const {
            'skipAuth': true,
            'skipDevice': true,
          },
        ),
      );

      final raw = response.data;
      if (raw is! Map) {
        throw ApiException(
          message: 'Bootstrap realtime invalide.',
          statusCode: response.statusCode,
          responseBody: raw,
        );
      }

      final map = Map<String, dynamic>.from(raw);
      final envelope = ApiEnvelope.parseResponse(map);
      if (envelope.data is Map) {
        return PosBootstrapConfig.fromJson({
          'data': Map<String, dynamic>.from(envelope.data as Map),
        });
      }
      return PosBootstrapConfig.fromJson(map);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Bootstrap realtime impossible: $e');
    }
  }
}

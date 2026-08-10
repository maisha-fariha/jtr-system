import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../models/api_envelope.dart';
import '../models/customer_info.dart';

class CustomerRemoteDataSource {
  CustomerRemoteDataSource(this._client);

  final ApiClient _client;

  /// [GET /api/customers/shortlist]
  Future<List<CustomerInfo>> fetchShortlist({String? query}) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.customersShortlist,
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (query != null && query.trim().isNotEmpty) 'search': query.trim(),
      },
    );
    final envelope = ApiEnvelope<dynamic>.fromJson(
      response.data!,
      (json) => json,
    );
    if (!envelope.success) {
      throw ApiException(
        message: envelope.message ?? 'Impossible de charger les clients.',
        statusCode: envelope.status,
      );
    }
    return CustomerInfo.listFromPayload(envelope.data);
  }

  /// [POST /api/customers]
  Future<CustomerInfo> createCustomer({
    required String name,
    String? phoneNumber,
    String? email,
  }) async {
    final body = <String, dynamic>{
      'name': name.trim(),
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
        'phone_number': phoneNumber.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
    };
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.customers,
      data: body,
    );
    final envelope = ApiEnvelope<dynamic>.fromJson(
      response.data!,
      (json) => json,
    );
    if (!envelope.success) {
      throw ApiException(
        message: envelope.message ?? 'Impossible de créer le client.',
        statusCode: envelope.status,
      );
    }
    final created = CustomerInfo.fromPayload(envelope.data);
    if (created == null || created.id <= 0) {
      throw ApiException(message: 'Réponse client invalide.');
    }
    return created;
  }
}

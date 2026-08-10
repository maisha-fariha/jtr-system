import '../../core/network/api_exception.dart';
import '../../services/connectivity_service.dart';
import '../datasources/customer_remote_datasource.dart';
import '../models/customer_info.dart';

class CustomerRepository {
  CustomerRepository({
    required CustomerRemoteDataSource remote,
    required ConnectivityService connectivity,
  })  : _remote = remote,
        _connectivity = connectivity;

  final CustomerRemoteDataSource _remote;
  final ConnectivityService _connectivity;

  List<CustomerInfo> _memory = const [];

  List<CustomerInfo> get cachedShortlist =>
      List<CustomerInfo>.unmodifiable(_memory);

  Future<List<CustomerInfo>> getShortlist({
    String? query,
    bool forceRefresh = false,
  }) async {
    final q = query?.trim() ?? '';
    if (!forceRefresh && q.isEmpty && _memory.isNotEmpty) {
      return cachedShortlist;
    }
    if (!await _connectivity.isOnline) {
      if (_memory.isNotEmpty) {
        if (q.isEmpty) return cachedShortlist;
        return _filterLocal(q);
      }
      throw ApiException(message: 'Clients indisponibles hors ligne.');
    }
    final list = await _remote.fetchShortlist(query: q.isEmpty ? null : q);
    if (q.isEmpty) _memory = list;
    return list;
  }

  Future<CustomerInfo> createCustomer({
    required String name,
    String? phoneNumber,
    String? email,
  }) async {
    if (!await _connectivity.isOnline) {
      throw ApiException(
        message: 'Création client impossible hors ligne.',
      );
    }
    final created = await _remote.createCustomer(
      name: name,
      phoneNumber: phoneNumber,
      email: email,
    );
    _memory = [created, ..._memory.where((c) => c.id != created.id)];
    return created;
  }

  List<CustomerInfo> _filterLocal(String query) {
    final lower = query.toLowerCase();
    return [
      for (final c in _memory)
        if (c.displayName.toLowerCase().contains(lower) ||
            (c.phoneNumber?.toLowerCase().contains(lower) ?? false) ||
            (c.email?.toLowerCase().contains(lower) ?? false))
          c,
    ];
  }
}

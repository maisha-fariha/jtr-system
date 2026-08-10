/// Customer (cardex) from [GET /api/customers/shortlist] / create.
class CustomerInfo {
  const CustomerInfo({
    required this.id,
    required this.name,
    this.phoneNumber,
    this.email,
  });

  final int id;
  final String name;
  final String? phoneNumber;
  final String? email;

  String get displayName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Client #$id';
    return trimmed;
  }

  String get subtitle {
    final phone = phoneNumber?.trim() ?? '';
    final mail = email?.trim() ?? '';
    if (phone.isNotEmpty && mail.isNotEmpty) return '$phone · $mail';
    if (phone.isNotEmpty) return phone;
    if (mail.isNotEmpty) return mail;
    return '';
  }

  factory CustomerInfo.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final name = (json['name'] ?? json['full_name'] ?? json['label'] ?? '')
        .toString()
        .trim();
    return CustomerInfo(
      id: id,
      name: name.isEmpty ? 'Client $id' : name,
      phoneNumber: (json['phone_number'] ?? json['phone'] ?? json['mobile'])
          ?.toString(),
      email: json['email']?.toString(),
    );
  }

  static List<CustomerInfo> listFromPayload(dynamic data) {
    List<dynamic>? raw;
    if (data is List) {
      raw = data;
    } else if (data is Map<String, dynamic>) {
      final nested = data['customers'] ??
          data['data'] ??
          data['items'] ??
          data['shortlist'];
      if (nested is List) raw = nested;
    }
    if (raw == null) return const [];

    final list = raw
        .whereType<Map>()
        .map((e) => CustomerInfo.fromJson(Map<String, dynamic>.from(e)))
        .where((c) => c.id > 0)
        .toList();
    list.sort(
      (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return list;
  }

  static CustomerInfo? fromPayload(dynamic data) {
    if (data is Map<String, dynamic>) {
      final nested = data['customer'];
      if (nested is Map) {
        return CustomerInfo.fromJson(Map<String, dynamic>.from(nested));
      }
      return CustomerInfo.fromJson(data);
    }
    return null;
  }
}

import '../../data/models/auth_user_model.dart';

/// Permission keys from `GET /api/permissions` (grouped in API response).
class PosPermissions {
  PosPermissions._();

  static const accessEditTableDetails = 'access-edit-table-details';

  /// Parses permission keys from login user payload (`permissions` list).
  static Set<String> keysFromUser(AuthUserModel? user) {
    if (user == null) return const {};

    final keys = <String>{};
    for (final raw in user.permissions) {
      if (raw is String) {
        final key = raw.trim();
        if (key.isNotEmpty) keys.add(key);
        continue;
      }
      if (raw is Map) {
        final key = raw['key']?.toString().trim();
        if (key != null && key.isNotEmpty) keys.add(key);
      }
    }
    return keys;
  }

  /// True when the user may delete/decrease lines after kitchen send.
  static bool canEditTableDetailsAfterSend(AuthUserModel? user) {
    if (user == null) return false;
    if (user.isSuperuser == true) return true;

    final keys = keysFromUser(user);
    return keys.contains(accessEditTableDetails);
  }
}

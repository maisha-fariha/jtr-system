import '../../data/models/auth_user_model.dart';

/// Permission keys from `GET /api/permissions` (grouped in API response).
class PosPermissions {
  PosPermissions._();

  // Payment
  static const accessPaymentButton = 'access-payment-button';

  // Order
  static const accessStockVisual = 'access-stock-visual';
  static const accessCloseDay = 'access-close-day';

  // Table
  static const accessEditTableDetails = 'access-edit-table-details';
  static const accessTableLockOverride = 'access-table-lock-override';

  // Authentication
  static const accessDashboard = 'access-dashboard';

  /// Keys that imply floor-wide visibility (manager / cashier style).
  /// All keys exist on `GET /api/permissions`.
  static const _viewAllOpenOrdersKeys = <String>{
    accessPaymentButton,
    accessEditTableDetails,
    accessStockVisual,
    accessCloseDay,
    accessDashboard,
    accessTableLockOverride,
  };

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

  /// True when the user may open Stock Visuel manager UI.
  static bool canAccessStockVisual(AuthUserModel? user) {
    if (user == null) return false;
    if (user.isSuperuser == true) return true;

    final keys = keysFromUser(user);
    return keys.contains(accessStockVisual);
  }

  /// Manager / cashier / admin: see every waiter's open (and paid) orders.
  ///
  /// Uses only keys from `GET /api/permissions` (no invented keys), plus
  /// common role name fallbacks when the role string is present.
  static bool canViewAllOpenOrders(AuthUserModel? user) {
    if (user == null) return false;
    if (user.isSuperuser == true) return true;

    final keys = keysFromUser(user);
    for (final key in _viewAllOpenOrdersKeys) {
      if (keys.contains(key)) return true;
    }

    final role = (user.role ?? '').toLowerCase().trim();
    if (role.isEmpty) return false;

    const roleNeedles = <String>[
      'manager',
      'gérant',
      'gerant',
      'cashier',
      'caissier',
      'caisse',
      'admin',
      'administrateur',
    ];
    for (final needle in roleNeedles) {
      if (role.contains(needle)) return true;
    }
    return false;
  }
}

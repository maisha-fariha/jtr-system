import '../../data/models/auth_user_model.dart';

/// Permission keys from `GET /api/permissions` (grouped in API response).
class PosPermissions {
  PosPermissions._();

  // Payment
  static const accessPaymentButton = 'access-payment-button';
  static const accessEditPaymentTransaction = 'access-edit-payment-transaction';
  static const accessDeletePaymentTransaction =
      'access-delete-payment-transaction';

  // Order
  static const accessStockVisual = 'access-stock-visual';
  static const accessCloseDay = 'access-close-day';
  static const accessPrintButton = 'access-print-button';
  static const accessOffert = 'access-offert';

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

  /// True when the user may print / ticket (session + table-details).
  static bool canPrintTicket(AuthUserModel? user) {
    if (user == null) return false;
    if (user.isSuperuser == true) return true;

    return keysFromUser(user).contains(accessPrintButton);
  }

  /// True when the user may open payment (cash / card).
  static bool canAccessPayment(AuthUserModel? user) {
    if (user == null) return false;
    if (user.isSuperuser == true) return true;

    return keysFromUser(user).contains(accessPaymentButton);
  }

  static bool canEditPaymentTransaction(AuthUserModel? user) {
    if (user == null) return false;
    if (user.isSuperuser == true) return true;
    return keysFromUser(user).contains(accessEditPaymentTransaction);
  }

  static bool canDeletePaymentTransaction(AuthUserModel? user) {
    if (user == null) return false;
    if (user.isSuperuser == true) return true;
    return keysFromUser(user).contains(accessDeletePaymentTransaction);
  }

  /// True when the user may offer a line or table (offert).
  static bool canAccessOffert(AuthUserModel? user) {
    if (user == null) return false;
    if (user.isSuperuser == true) return true;

    return keysFromUser(user).contains(accessOffert);
  }

  /// True when the user may open Statistics.
  static bool canAccessStatistics(AuthUserModel? user) {
    if (user == null) return false;
    if (user.isSuperuser == true) return true;

    return keysFromUser(user).contains(accessDashboard);
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

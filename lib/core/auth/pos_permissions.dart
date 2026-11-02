import '../../data/models/auth_user_model.dart';

/// Permission keys from login `user.permissions` (exact backend strings).
///
/// Source: JTR POS — Permissions (Mobile Implementation Guide).
class PosPermissions {
  PosPermissions._();

  // Payment
  static const accessPaymentButton = 'access-payment-button';
  static const accessEditPaymentTransaction = 'access-edit-payment-transaction';
  static const accessDeletePaymentTransaction =
      'access-delete-payment-transaction';

  // Order
  static const accessPrintButton = 'access-print-button';
  static const accessSeparateButton = 'access-separate-button';
  static const accessTransferButton = 'access-transfer-button';
  static const accessAnnulationTable = 'access-annulation-table';
  static const accessAnnulationSeat = 'access-annulation-seat';
  static const accessAnnulationArticle = 'access-annulation-article';
  static const accessOffert = 'access-offert';
  static const accessRemise = 'access-remise';
  static const accessTableLoss = 'access-table-loss';
  static const accessSeatLoss = 'access-seat-loss';
  static const accessArticleLoss = 'access-article-loss';
  static const accessStockVisual = 'access-stock-visual';
  static const accessCloseDay = 'access-close-day';
  static const accessPosDashboard = 'access-pos-dashboard';
  static const accessPosChat = 'access-pos-chat';

  // Table
  static const accessTableLockOverride = 'access-table-lock-override';
  static const accessEditTableDetails = 'access-edit-table-details';

  // Authentication (admin web — not used to gate mobile POS UI)
  static const accessDashboard = 'access-dashboard';

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

  /// Mirrors desktop `hasPermission`.
  static bool hasPermission(AuthUserModel? user, String permission) {
    if (user == null) return false;
    if (user.isSuperuser == true) return true;
    return keysFromUser(user).contains(permission);
  }

  /// Mirrors desktop `hasAnyPermission`.
  static bool hasAnyPermission(
    AuthUserModel? user,
    Iterable<String> permissions,
  ) {
    if (user == null) return false;
    if (user.isSuperuser == true) return true;
    final keys = keysFromUser(user);
    for (final permission in permissions) {
      if (keys.contains(permission)) return true;
    }
    return false;
  }

  /// Cancel entire table (`access-annulation-table`).
  static bool canCancelTable(AuthUserModel? user) =>
      hasPermission(user, accessAnnulationTable);

  /// Cancel seat / course / À SUIVRE section with sent items.
  static bool canCancelSeat(AuthUserModel? user) =>
      hasPermission(user, accessAnnulationSeat);

  /// Cancel a sent article (`access-annulation-article`).
  /// Unsent lines do not require this — callers must check sent state.
  static bool canCancelSentArticle(AuthUserModel? user) =>
      hasPermission(user, accessAnnulationArticle);

  /// True when the user may delete/decrease **sent** kitchen lines.
  @Deprecated('Use canCancelSentArticle')
  static bool canEditTableDetailsAfterSend(AuthUserModel? user) =>
      canCancelSentArticle(user);

  /// True when the user may open Stock Visuel manager UI.
  static bool canAccessStockVisual(AuthUserModel? user) =>
      hasPermission(user, accessStockVisual);

  /// True when the user may print / ticket (session + table-details).
  static bool canPrintTicket(AuthUserModel? user) =>
      hasPermission(user, accessPrintButton);

  /// True when the user may open payment (cash / card).
  static bool canAccessPayment(AuthUserModel? user) =>
      hasPermission(user, accessPaymentButton);

  static bool canEditPaymentTransaction(AuthUserModel? user) =>
      hasPermission(user, accessEditPaymentTransaction);

  static bool canDeletePaymentTransaction(AuthUserModel? user) =>
      hasPermission(user, accessDeletePaymentTransaction);

  /// True when the user may offer a line or table (offert).
  static bool canAccessOffert(AuthUserModel? user) =>
      hasPermission(user, accessOffert);

  /// POS Statistics / analytics (`access-pos-dashboard`).
  ///
  /// Not [accessDashboard] — that key is admin web only.
  static bool canAccessStatistics(AuthUserModel? user) =>
      hasPermission(user, accessPosDashboard);

  /// JTR Mobile / Rapport manager dashboard (`access-pos-dashboard`).
  static bool canAccessJtrMobileDashboard(AuthUserModel? user) =>
      hasPermission(user, accessPosDashboard);

  /// POS AI chat (`access-pos-chat`).
  static bool canAccessPosChat(AuthUserModel? user) =>
      hasPermission(user, accessPosChat);

  /// Open a table locked by another user.
  static bool canOverrideTableLock(AuthUserModel? user) => hasAnyPermission(
        user,
        const [accessTableLockOverride, accessEditTableDetails],
      );

  /// Edit table details / choose waiter.
  static bool canEditTableDetails(AuthUserModel? user) =>
      hasPermission(user, accessEditTableDetails);

  /// Manager / cashier: see every waiter's open (and paid) orders.
  ///
  /// Desktop TableList uses [accessEditTableDetails] only.
  static bool canViewAllOpenOrders(AuthUserModel? user) =>
      hasPermission(user, accessEditTableDetails);
}

class ApiEndpoints {
  ApiEndpoints._();

  static const deviceSession = '/api/devices/session';
  static const deviceActivate = '/api/devices/activate';

  /// Reverb config (no auth / no device headers per mobile guide).
  static const posBootstrap = '/api/pos/bootstrap';
  static const broadcastingAuth = '/api/broadcasting/auth';

  static const loginUsers = '/api/auth/login-users';
  static const loginRoles = '/api/auth/login-roles';
  static const login = '/api/auth/login';
  static const permissions = '/api/permissions';

  static const activeDay = '/api/days/active';
  static const activeDayStatistics = '/api/dashboard/active-day-statistics';
  static const salesZonesShortlist = '/api/sales-zones/shortlist';
  static const orders = '/api/orders';
  static const createOrder = orders;
  static const openOrders = '/api/days/open-orders';
  static const markOrderPrinted = '/api/orders/mark-printed';
  static const generateReceipt = '/api/receipts/generate';
  static const tablesList = '/api/tables/list';
  static const tables = '/api/tables';
  static const openTableByNumber = '/api/tables/open-by-number';
  static String tableById(int tableId) => '/api/tables/$tableId';
  static String tableSession(int tableId) => '/api/tables/$tableId/session';

  static String orderById(int id) => '/api/orders/$id';
  static String closeOrder(int id) => '/api/orders/$id/close';
  static String requestCourses(int id) => '/api/orders/$id/request-courses';
  static String orderSeatOrderItems(int orderId, int seatNumber) =>
      '/api/orders/$orderId/seat-orders/$seatNumber/items';
  static String payOrder(int id) => '/api/orders/$id/pay';
  static const paymentModesForCheckout = '/api/payments/modes';
  static const activePaymentModes = '/api/payment-modes/active';
  static const paymentModesList = '/api/payment-modes';
  static const paymentSettings = '/api/payments/settings';
  static String dayStatistics(int dayId) => '/api/days/$dayId/statistics';

  static const categoriesLeafOnly = '/api/categories/leaf-only';
  static const categoriesTree = '/api/categories/tree';
  static const productsList = '/api/products/list';
  static String productById(int id) => '/api/products/$id';

  // Stock Visuel (daily remaining qty). Soft-fail callers must not block orders.
  static const stockLimits = '/api/stock/limits';
  static String stockLimitForProduct(int productId) =>
      '/api/stock/limits/product/$productId';
  static const stockApplyDeltas = '/api/stock/apply-deltas';
  static String stockProductStatus(int productId) =>
      '/api/stock/product/$productId/status';
  static String stockProductBlock(int productId) =>
      '/api/stock/product/$productId/block';
  static String stockProductFree(int productId) =>
      '/api/stock/product/$productId/free';
}

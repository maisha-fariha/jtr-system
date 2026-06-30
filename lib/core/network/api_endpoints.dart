class ApiEndpoints {
  ApiEndpoints._();

  static const loginUsers = '/api/auth/login-users';
  static const loginRoles = '/api/auth/login-roles';
  static const login = '/api/auth/login';

  static const activeDay = '/api/days/active';
  static const activeDayStatistics = '/api/dashboard/active-day-statistics';
  static const orders = '/api/orders';
  static const createOrder = orders;
  static const openOrders = '/api/days/open-orders';
  static const markOrderPrinted = '/api/orders/mark-printed';
  static const tablesList = '/api/tables/list';
  static const tables = '/api/tables';
  static String tableById(int tableId) => '/api/tables/$tableId';
  static String tableSession(int tableId) => '/api/tables/$tableId/session';

  static String orderById(int id) => '/api/orders/$id';
  static String closeOrder(int id) => '/api/orders/$id/close';
  static String requestCourses(int id) => '/api/orders/$id/request-courses';
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
  static const menuCategories = '/api/menu-categories';
}

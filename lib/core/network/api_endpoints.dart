class ApiEndpoints {
  ApiEndpoints._();

  static const loginUsers = '/api/auth/login-users';
  static const loginRoles = '/api/auth/login-roles';
  static const login = '/api/auth/login';

  static const activeDay = '/api/days/active';
  static const activeDayStatistics = '/api/dashboard/active-day-statistics';
  static const createOrder = '/api/orders';
  static const markOrderPrinted = '/api/orders/mark-printed';
  static const tablesList = '/api/tables/list';
  static const tables = '/api/tables';
  static String tableById(int tableId) => '/api/tables/$tableId';
  static String tableSession(int tableId) => '/api/tables/$tableId/session';

  static String orderById(int id) => '/api/orders/$id';
  static String closeOrder(int id) => '/api/orders/$id/close';
  static String requestCourses(int id) => '/api/orders/$id/request-courses';
  static String dayStatistics(int dayId) => '/api/days/$dayId/statistics';
}

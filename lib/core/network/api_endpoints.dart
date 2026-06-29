class ApiEndpoints {
  ApiEndpoints._();

  static const loginUsers = '/api/auth/login-users';
  static const loginRoles = '/api/auth/login-roles';
  static const login = '/api/auth/login';

  static const openOrders = '/api/days/open-orders';
  static String orderById(int id) => '/api/orders/$id';
  static String closeOrder(int id) => '/api/orders/$id/close';
}

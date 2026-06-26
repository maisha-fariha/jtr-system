import 'package:get/get.dart';

import '../controllers/connect_controller.dart';
import '../controllers/login_controller.dart';
import '../controllers/order_menu_controller.dart';
import '../controllers/session_controller.dart';
import '../pages/connect_page.dart';
import '../pages/home_page.dart';
import '../pages/login_page.dart';
import '../pages/menu_page.dart';
import '../pages/session_page.dart';
import '../pages/statistics_page.dart';

class AppRoutes {
  static const root = '/';
  static const home = '/home';
  static const connect = '/connect';
  static const login = '/login';
  static const session = '/session';
  static const menu = '/menu';
  static const statistics = '/statistics';
}

class AppPages {
  AppPages._();

  static final routes = <GetPage>[
    GetPage(
      name: AppRoutes.root,
      page: () => const HomePage(),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const HomePage(),
    ),
    GetPage(
      name: AppRoutes.connect,
      page: () => const ConnectPage(),
      binding: BindingsBuilder(() {
        Get.put(ConnectController());
      }),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginPage(),
      binding: BindingsBuilder(() {
        Get.put(LoginController());
      }),
    ),
    GetPage(
      name: AppRoutes.session,
      page: () => const SessionPage(),
      binding: BindingsBuilder(() {
        Get.put(SessionController());
      }),
    ),
    GetPage(
      name: AppRoutes.menu,
      page: () => const MenuPage(),
      binding: BindingsBuilder(() {
        Get.put(OrderMenuController());
      }),
    ),
    GetPage(
      name: AppRoutes.statistics,
      page: () => const StatisticsPage(),
    ),
  ];
}

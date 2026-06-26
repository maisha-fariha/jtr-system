import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import '../controllers/login_controller.dart';
import '../controllers/order_menu_controller.dart';
import '../controllers/session_controller.dart';
import '../pages/connect_page.dart';
import '../pages/home_page.dart';
import '../pages/login_page.dart';
import '../pages/menu_page.dart';
import '../pages/session_page.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static final routes = <GetPage>[
    GetPage(
      name: AppRoutes.home,
      page: () => const HomePage(),
      binding: BindingsBuilder.put(() => HomeController()),
    ),
    GetPage(
      name: AppRoutes.connect,
      page: () => const ConnectPage(),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginPage(),
      binding: BindingsBuilder.put(() => LoginController()),
    ),
    GetPage(
      name: AppRoutes.session,
      page: () => const SessionPage(),
      binding: BindingsBuilder.put(() => SessionController()),
    ),
    GetPage(
      name: AppRoutes.menu,
      page: () => const MenuPage(),
      binding: BindingsBuilder.put(() => OrderMenuController()),
    ),
  ];
}

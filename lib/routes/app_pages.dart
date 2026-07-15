import 'package:get/get.dart';

import '../controllers/connect_controller.dart';
import '../controllers/device_activation_controller.dart';
import '../controllers/device_blocked_controller.dart';
import '../controllers/device_gate_controller.dart';
import '../controllers/login_controller.dart';
import '../controllers/menu_selection_controller.dart';
import '../controllers/order_menu_controller.dart';
import '../controllers/session_controller.dart';
import '../pages/connect_page.dart';
import '../pages/device_activation_page.dart';
import '../pages/device_blocked_page.dart';
import '../pages/device_gate_page.dart';
import '../pages/home_page.dart';
import '../pages/login_page.dart';
import '../pages/menu_page.dart';
import '../pages/menu_selection_page.dart';
import '../pages/session_page.dart';
import '../pages/statistics_page.dart';
import '../controllers/table_details_controller.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/repositories/device_repository.dart';
import '../data/repositories/order_repository.dart';
import '../data/repositories/session_repository.dart';
import '../pages/table_details_page.dart';

class AppRoutes {
  static const root = '/';
  static const home = '/home';
  static const deviceGate = '/device-gate';
  static const activation = '/activation';
  static const deviceBlocked = '/device-blocked';
  static const connect = '/connect';
  static const login = '/login';
  static const session = '/session';
  static const menu = '/menu';
  static const menuSelection = '/menu-selection';
  static const tableDetails = '/table-details';
  static const statistics = '/statistics';
}

class AppPages {
  AppPages._();

  static final routes = <GetPage>[
    GetPage(
      name: AppRoutes.root,
      page: () => const DeviceGatePage(),
      binding: BindingsBuilder(() {
        Get.put(
          DeviceGateController(
            deviceRepository: Get.find<DeviceRepository>(),
          ),
        );
      }),
    ),
    GetPage(
      name: AppRoutes.deviceGate,
      page: () => const DeviceGatePage(),
      binding: BindingsBuilder(() {
        Get.put(
          DeviceGateController(
            deviceRepository: Get.find<DeviceRepository>(),
          ),
        );
      }),
    ),
    GetPage(
      name: AppRoutes.activation,
      page: () => const DeviceActivationPage(),
      binding: BindingsBuilder(() {
        Get.put(
          DeviceActivationController(
            deviceRepository: Get.find<DeviceRepository>(),
            authRepository: Get.find<AuthRepository>(),
          ),
        );
      }),
    ),
    GetPage(
      name: AppRoutes.deviceBlocked,
      page: () => const DeviceBlockedPage(),
      binding: BindingsBuilder(() {
        Get.put(
          DeviceBlockedController(
            deviceRepository: Get.find<DeviceRepository>(),
            authRepository: Get.find<AuthRepository>(),
          ),
        );
      }),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const HomePage(),
    ),
    GetPage(
      name: AppRoutes.connect,
      page: () => const ConnectPage(),
      binding: BindingsBuilder(() {
        Get.put(ConnectController(authRepository: Get.find<AuthRepository>()));
      }),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginPage(),
      binding: BindingsBuilder(() {
        Get.put(LoginController(authRepository: Get.find<AuthRepository>()));
      }),
    ),
    GetPage(
      name: AppRoutes.session,
      page: () => const SessionPage(),
      binding: BindingsBuilder(() {
        Get.put(
          SessionController(
            orderRepository: Get.find<OrderRepository>(),
            sessionRepository: Get.find<SessionRepository>(),
            authRepository: Get.find<AuthRepository>(),
          ),
        );
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
      name: AppRoutes.menuSelection,
      page: () => const MenuSelectionPage(),
      binding: BindingsBuilder(() {
        Get.put(
          MenuSelectionController(
            catalogRepository: Get.find<CatalogRepository>(),
            orderRepository: Get.find<OrderRepository>(),
          ),
        );
      }),
    ),
    GetPage(
      name: AppRoutes.tableDetails,
      page: () => const TableDetailsPage(),
      binding: BindingsBuilder(() {
        Get.put(
          TableDetailsController(
            catalogRepository: Get.find<CatalogRepository>(),
            orderRepository: Get.find<OrderRepository>(),
          ),
        );
      }),
    ),
    GetPage(
      name: AppRoutes.statistics,
      page: () => const StatisticsPage(),
    ),
  ];
}

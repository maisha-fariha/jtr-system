import 'package:get/get.dart';

import '../routes/app_pages.dart';

class AppNavigation {
  AppNavigation._();

  static void logout() => Get.offAllNamed(AppRoutes.home);
}

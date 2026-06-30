import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'bindings/app_binding.dart';
import 'controllers/theme_controller.dart';
import 'core/storage/hive_storage.dart';
import 'data/repositories/auth_repository.dart';
import 'routes/app_pages.dart';
import 'utils/app_theme.dart';
import 'utils/responsive.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppBinding().dependencies();
  await Get.find<HiveStorage>().init();
  await Get.find<AuthRepository>().restoreSessionOnAppStart();
  runApp(const JtrSystemApp());
}

class JtrSystemApp extends StatelessWidget {
  const JtrSystemApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return ScreenUtilInit(
      designSize: const Size(
        JtrResponsive.baseWidth,
        JtrResponsive.baseHeight,
      ),
      minTextAdapt: true,
      builder: (context, child) {
        return Obx(
          () => GetMaterialApp(
            title: 'JTR System',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeController.isDark.value
                ? ThemeMode.dark
                : ThemeMode.light,
            getPages: AppPages.routes,
            initialRoute: AppRoutes.home,
            debugShowCheckedModeBanner: false,
          ),
        );
      },
    );
  }
}

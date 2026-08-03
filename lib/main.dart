import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'bindings/app_binding.dart';
import 'controllers/theme_controller.dart';
import 'core/storage/hive_storage.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/device_repository.dart';
import 'routes/app_pages.dart';
import 'services/reverb_realtime_service.dart';
import 'utils/app_theme.dart';
import 'utils/responsive.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppBinding().dependencies();
  await Get.find<HiveStorage>().init();
  // Restore device headers before any API call (login session restore too).
  await Get.find<DeviceRepository>().restoreRuntimeFromStorage();
  final restored = await Get.find<AuthRepository>().restoreSessionOnAppStart();
  if (restored) {
    // Fire-and-forget: bootstrap + WS after device + Sanctum are restored.
    // ignore: unawaited_futures
    Get.find<ReverbRealtimeService>().start();
  }
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
            initialRoute: AppRoutes.deviceGate,
            debugShowCheckedModeBanner: false,
          ),
        );
      },
    );
  }
}

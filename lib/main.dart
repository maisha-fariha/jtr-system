import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'controllers/theme_controller.dart';
import 'routes/app_pages.dart';
import 'utils/app_theme.dart';

void main() {
  // ThemeController must be available before the first route builds.
  Get.put(ThemeController());
  runApp(const JtrSystemApp());
}

class JtrSystemApp extends StatelessWidget {
  const JtrSystemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'JTR System',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      getPages: AppPages.routes,
      initialRoute: AppRoutes.home,
      debugShowCheckedModeBanner: false,
    );
  }
}

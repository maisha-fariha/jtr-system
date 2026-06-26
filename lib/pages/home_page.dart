import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import '../utils/app_theme.dart';

class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header bar
            Container(
              height: 56,
              color: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.restaurant_menu,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'JTR SYSTEM',
                    style: AppTheme.title1.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo / illustration
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primary.withValues(alpha: 0.12),
                        ),
                        child: const Icon(Icons.restaurant,
                            size: 60, color: AppTheme.primary),
                      ),
                      const SizedBox(height: 28),
                      Text('Bienvenue',
                          style: AppTheme.headline1
                              .copyWith(color: AppTheme.primary)),
                      const SizedBox(height: 8),
                      Text(
                        'Système de prise de commande',
                        style: AppTheme.body1
                            .copyWith(color: AppTheme.textMedium),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: controller.navigateToConnect,
                          child: const Text('COMMENCER'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            _AppFooter(),
          ],
        ),
      ),
    );
  }
}

class _AppFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: AppTheme.surfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('v1.0.0', style: AppTheme.caption),
          Text('© 2025 JTR', style: AppTheme.caption),
        ],
      ),
    );
  }
}

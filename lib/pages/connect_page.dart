import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../routes/app_routes.dart';
import '../utils/app_theme.dart';

class ConnectPage extends StatelessWidget {
  const ConnectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              height: 56,
              color: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: Get.back,
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text('CONNEXION',
                      style: AppTheme.title1
                          .copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
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
                      const Icon(Icons.lock_outline,
                          size: 64, color: AppTheme.primary),
                      const SizedBox(height: 20),
                      Text('Sélectionnez votre point de vente',
                          style: AppTheme.title1,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 32),
                      _PointOfSaleCard(
                        name: 'Restaurant Principal',
                        address: 'Zone A — Salle principale',
                        onTap: () => Get.toNamed(AppRoutes.login),
                      ),
                      const SizedBox(height: 12),
                      _PointOfSaleCard(
                        name: 'Terrasse',
                        address: 'Zone B — Terrasse extérieure',
                        onTap: () => Get.toNamed(AppRoutes.login),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointOfSaleCard extends StatelessWidget {
  const _PointOfSaleCard({
    required this.name,
    required this.address,
    required this.onTap,
  });

  final String name;
  final String address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.subtleShadow,
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.storefront, color: AppTheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTheme.title2),
                  const SizedBox(height: 2),
                  Text(address, style: AppTheme.body2),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textLight),
          ],
        ),
      ),
    );
  }
}

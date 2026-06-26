import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/theme_controller.dart';
import '../routes/app_pages.dart';
import '../utils/app_theme.dart';
import '../widgets/app_footer.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Get.back();
            } else {
              SystemNavigator.pop();
            }
          },
        ),
        centerTitle: false,
        title: const Text('JTR System'),
        actions: [
          // ── Theme toggle ──────────────────────────────────────────────────
          Obx(() {
            final dark = ThemeController.to.isDark.value;
            return IconButton(
              tooltip: dark ? 'Mode clair' : 'Mode sombre',
              onPressed: ThemeController.to.toggle,
              icon: Icon(
                dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: AppTheme.primary,
              ),
            );
          }),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: AppTheme.background,
            onSelected: (_) {},
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'about',
                child: Text('About'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 48),
              _buildBrandHeader(),
              const Spacer(),
              _buildConnectButton(),
              const SizedBox(height: 20),
              _buildExitButton(),
              const Spacer(flex: 2),
              const AppFooter(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Image.asset(
      'assets/images/logo_text.png',
      fit: BoxFit.contain,
    );
  }

  Widget _buildConnectButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () => Get.toNamed(AppRoutes.connect),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppTheme.primary.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Connect',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildExitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () => SystemNavigator.pop(),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.lightButton,
          foregroundColor: AppTheme.darkText,
          elevation: 4,
          shadowColor: AppTheme.primary.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Exit',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

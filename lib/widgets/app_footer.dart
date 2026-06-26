import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/theme_controller.dart';
import '../utils/app_theme.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      ThemeController.to.isDark.value;
      const email = 'contact.jtrinnovation@gmail.com';

      return Column(
        children: [
          Text(
            'All rights and license ganted by JTR Ennovation.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.darkText.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Contact: +212 8 08 58 51 28 / +212 6 66 44 43 30',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.darkText.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.darkText.withValues(alpha: 0.8),
                height: 1.5,
              ),
              children: [
                const TextSpan(text: 'Email: '),
                TextSpan(
                  text: email,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const TextSpan(text: ' "to be modified"'),
              ],
            ),
          ),
        ],
      );
    });
  }
}

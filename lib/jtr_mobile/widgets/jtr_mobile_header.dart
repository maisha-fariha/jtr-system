import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/theme_controller.dart';
import '../../utils/responsive.dart';
import '../theme/jtr_mobile_theme.dart';

class JtrMobileHeader extends StatelessWidget {
  const JtrMobileHeader({
    super.key,
    required this.storeName,
    required this.dateLabel,
    required this.onChatTap,
    required this.onThemeTap,
  });

  final String storeName;
  final String dateLabel;
  final VoidCallback onChatTap;
  final VoidCallback onThemeTap;

  @override
  Widget build(BuildContext context) {
    final iconSize = JtrResponsive.getResponsiveSize(context, 34);
    final isDark = Get.isRegistered<ThemeController>()
        ? Get.find<ThemeController>().isDark.value
        : false;

    return Padding(
      padding: EdgeInsets.only(
        bottom: JtrResponsive.getResponsiveHeight(context, 16),
      ),
      child: Row(
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: JtrMobileTheme.accentBg,
              border: Border.all(color: JtrMobileTheme.border, width: 0.5),
            ),
            child: Icon(
              Icons.storefront_rounded,
              color: JtrMobileTheme.accent,
              size: JtrResponsive.getResponsiveSize(context, 18),
            ),
          ),
          SizedBox(width: JtrResponsive.getResponsiveWidth(context, 8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeName,
                  style: TextStyle(
                    fontSize: JtrResponsive.getResponsiveFontSize(context, 15),
                    fontWeight: FontWeight.w600,
                    color: JtrMobileTheme.textPrimary,
                  ),
                ),
                SizedBox(height: JtrResponsive.getResponsiveHeight(context, 2)),
                Row(
                  children: [
                    Container(
                      width: JtrResponsive.getResponsiveSize(context, 6),
                      height: JtrResponsive.getResponsiveSize(context, 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: JtrMobileTheme.success,
                      ),
                    ),
                    SizedBox(width: JtrResponsive.getResponsiveWidth(context, 5)),
                    Flexible(
                      child: Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize:
                              JtrResponsive.getResponsiveFontSize(context, 12),
                          color: JtrMobileTheme.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onChatTap,
            icon: Icon(
              Icons.chat_bubble_outline_rounded,
              color: JtrMobileTheme.textSecondary,
              size: JtrResponsive.getResponsiveSize(context, 20),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          SizedBox(width: JtrResponsive.getResponsiveWidth(context, 12)),
          IconButton(
            onPressed: onThemeTap,
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: JtrMobileTheme.textSecondary,
              size: JtrResponsive.getResponsiveSize(context, 19),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          SizedBox(width: JtrResponsive.getResponsiveWidth(context, 4)),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: JtrMobileTheme.textMuted,
            size: JtrResponsive.getResponsiveSize(context, 20),
          ),
        ],
      ),
    );
  }
}

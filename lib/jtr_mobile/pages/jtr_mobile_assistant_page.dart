import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../utils/responsive.dart';
import '../../widgets/app_footer.dart';
import '../assistant/jtr_mobile_assistant_chat_view.dart';
import '../assistant/jtr_mobile_assistant_controller.dart';
import '../theme/jtr_mobile_theme.dart';
import '../widgets/jtr_mobile_theme_scope.dart';

/// Full-screen Assistant IA chat (shares [JtrMobileAssistantController]).
///
/// TEMPORARY mock page — remove with `assistant/` when backend API is ready.
class JtrMobileAssistantPage extends StatelessWidget {
  const JtrMobileAssistantPage({super.key});

  static Future<void> open() async {
    if (!Get.isRegistered<JtrMobileAssistantController>()) {
      Get.put(JtrMobileAssistantController());
    }
    await Get.to(() => const JtrMobileAssistantPage());
  }

  @override
  Widget build(BuildContext context) {
    final maxW = JtrMobileTheme.dashboardMaxWidth(context);

    return JtrMobileThemeScope(
      builder: (context) => Scaffold(
        backgroundColor: JtrMobileTheme.pageBackground,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: JtrResponsive.getResponsivePadding(
                  context,
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: _AssistantAppBar(),
                  ),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            margin: JtrResponsive.getResponsivePadding(
                              context,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: JtrMobileTheme.surfaceCard,
                              borderRadius: BorderRadius.circular(
                                JtrMobileTheme.cardRadius,
                              ),
                              border: Border.all(
                                color: JtrMobileTheme.border,
                                width: 0.5,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: const JtrMobileAssistantChatView(
                              expanded: true,
                            ),
                          ),
                        ),
                        Padding(
                          padding: JtrResponsive.getResponsivePadding(
                            context,
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: const AppFooter(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Get.back(),
            borderRadius: BorderRadius.circular(JtrMobileTheme.tileRadius),
            child: Padding(
              padding: JtrResponsive.getResponsivePadding(
                context,
                horizontal: 4,
                vertical: 4,
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: JtrMobileTheme.textSecondary,
                size: JtrResponsive.getResponsiveSize(context, 22),
              ),
            ),
          ),
        ),
        SizedBox(width: JtrResponsive.getResponsiveWidth(context, 4)),
        Icon(
          Icons.auto_awesome_rounded,
          size: JtrResponsive.getResponsiveSize(context, 20),
          color: JtrMobileTheme.accent,
        ),
        SizedBox(width: JtrResponsive.getResponsiveWidth(context, 8)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assistant IA',
                style: TextStyle(
                  fontSize: JtrResponsive.getResponsiveFontSize(context, 15),
                  fontWeight: FontWeight.w600,
                  color: JtrMobileTheme.textPrimary,
                ),
              ),
              Text(
                'Plein écran · démo locale',
                style: TextStyle(
                  fontSize: JtrResponsive.getResponsiveFontSize(context, 12),
                  color: JtrMobileTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: JtrResponsive.getResponsiveWidth(context, 8),
            vertical: JtrResponsive.getResponsiveHeight(context, 4),
          ),
          decoration: BoxDecoration(
            color: JtrMobileTheme.accentBg,
            borderRadius: BorderRadius.circular(JtrMobileTheme.tileRadius),
          ),
          child: Text(
            'Démo',
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 10),
              fontWeight: FontWeight.w600,
              color: JtrMobileTheme.accent,
            ),
          ),
        ),
      ],
    );
  }
}

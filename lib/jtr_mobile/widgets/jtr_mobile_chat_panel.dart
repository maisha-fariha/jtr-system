import 'package:flutter/material.dart';

import '../../utils/responsive.dart';
import '../assistant/jtr_mobile_assistant_chat_view.dart';
import '../pages/jtr_mobile_assistant_page.dart';
import '../theme/jtr_mobile_theme.dart';

/// Compact dashboard chat card. Opens [JtrMobileAssistantPage] for full screen.
///
/// TEMPORARY mock UI — remove mock wiring when backend assistant API is ready.
class JtrMobileChatPanel extends StatelessWidget {
  const JtrMobileChatPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final radius = JtrMobileTheme.cardRadius;
    return Container(
      margin: EdgeInsets.only(
        bottom: JtrResponsive.getResponsiveHeight(context, 12),
      ),
      decoration: BoxDecoration(
        color: JtrMobileTheme.surfaceCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: JtrMobileTheme.border, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: JtrResponsive.getResponsivePadding(
              context,
              horizontal: 14,
              vertical: 12,
            ),
            color: JtrMobileTheme.accentBg,
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: JtrResponsive.getResponsiveSize(context, 18),
                  color: JtrMobileTheme.accent,
                ),
                SizedBox(width: JtrResponsive.getResponsiveWidth(context, 8)),
                Expanded(
                  child: Text(
                    'Assistant IA',
                    style: TextStyle(
                      fontSize:
                          JtrResponsive.getResponsiveFontSize(context, 13),
                      fontWeight: FontWeight.w600,
                      color: JtrMobileTheme.textPrimary,
                    ),
                  ),
                ),
                Text(
                  'Démo',
                  style: TextStyle(
                    fontSize: JtrResponsive.getResponsiveFontSize(context, 10),
                    fontWeight: FontWeight.w600,
                    color: JtrMobileTheme.accent,
                  ),
                ),
                SizedBox(width: JtrResponsive.getResponsiveWidth(context, 6)),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => JtrMobileAssistantPage.open(),
                    borderRadius: BorderRadius.circular(
                      JtrMobileTheme.tileRadius,
                    ),
                    child: Padding(
                      padding: JtrResponsive.getResponsivePadding(
                        context,
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Icon(
                        Icons.open_in_full_rounded,
                        size: JtrResponsive.getResponsiveSize(context, 18),
                        color: JtrMobileTheme.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const JtrMobileAssistantChatView(expanded: false),
        ],
      ),
    );
  }
}

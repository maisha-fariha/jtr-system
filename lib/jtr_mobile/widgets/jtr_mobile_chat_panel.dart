import 'package:flutter/material.dart';

import '../../utils/responsive.dart';
import '../theme/jtr_mobile_theme.dart';

class JtrMobileChatPanel extends StatelessWidget {
  const JtrMobileChatPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final radius = JtrResponsive.getResponsiveRadius(context, 12);
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
                Text(
                  'Assistant IA',
                  style: TextStyle(
                    fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
                    fontWeight: FontWeight.w600,
                    color: JtrMobileTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: JtrResponsive.getResponsivePadding(
              context,
              horizontal: 14,
              vertical: 12,
            ),
            child: Container(
              padding: JtrResponsive.getResponsivePadding(
                context,
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: JtrMobileTheme.surfaceTile,
                borderRadius: BorderRadius.circular(
                  JtrResponsive.getResponsiveRadius(context, 10),
                ),
              ),
              child: Text(
                'Bonjour 👋 Je peux vous résumer vos ventes, expliquer un '
                'écart ou comparer deux périodes. Que voulez-vous savoir ?',
                style: TextStyle(
                  fontSize: JtrResponsive.getResponsiveFontSize(context, 12),
                  height: 1.5,
                  color: JtrMobileTheme.textPrimary,
                ),
              ),
            ),
          ),
          Padding(
            padding: JtrResponsive.getResponsivePadding(
              context,
              horizontal: 14,
              vertical: 0,
            ).copyWith(bottom: 14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Écrivez votre question...',
                      hintStyle: TextStyle(
                        fontSize:
                            JtrResponsive.getResponsiveFontSize(context, 12),
                        color: JtrMobileTheme.textMuted,
                      ),
                      filled: true,
                      fillColor: JtrMobileTheme.surfaceTile,
                      contentPadding: JtrResponsive.getResponsivePadding(
                        context,
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          JtrResponsive.getResponsiveRadius(context, 8),
                        ),
                        borderSide: BorderSide(
                          color: JtrMobileTheme.borderStrong,
                          width: 0.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          JtrResponsive.getResponsiveRadius(context, 8),
                        ),
                        borderSide: BorderSide(
                          color: JtrMobileTheme.borderStrong,
                          width: 0.5,
                        ),
                      ),
                    ),
                    style: TextStyle(
                      fontSize:
                          JtrResponsive.getResponsiveFontSize(context, 12),
                      color: JtrMobileTheme.textPrimary,
                    ),
                  ),
                ),
                SizedBox(width: JtrResponsive.getResponsiveWidth(context, 6)),
                Material(
                  color: JtrMobileTheme.accent,
                  borderRadius: BorderRadius.circular(
                    JtrResponsive.getResponsiveRadius(context, 8),
                  ),
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(
                      JtrResponsive.getResponsiveRadius(context, 8),
                    ),
                    child: SizedBox(
                      width: JtrResponsive.getResponsiveSize(context, 34),
                      height: JtrResponsive.getResponsiveSize(context, 34),
                      child: Icon(
                        Icons.send_rounded,
                        color: JtrMobileTheme.accentOnAccent,
                        size: JtrResponsive.getResponsiveSize(context, 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

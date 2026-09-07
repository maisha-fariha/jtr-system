import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../utils/responsive.dart';
import '../theme/jtr_mobile_theme.dart';
import 'jtr_mobile_theme_scope.dart';

class JtrMobileDetailScaffold extends StatelessWidget {
  const JtrMobileDetailScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxW = JtrMobileTheme.dashboardMaxWidth(context);
    final hPad = JtrResponsive.getResponsivePadding(
      context,
      horizontal: 16,
    ).horizontal;

    return JtrMobileThemeScope(
      builder: (context) => Scaffold(
      backgroundColor: JtrMobileTheme.pageBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                hPad / 2,
                JtrResponsive.getResponsiveHeight(context, 8),
                hPad / 2,
                JtrResponsive.getResponsiveHeight(context, 8),
              ),
              child: Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: _BackHeader(title: title, subtitle: subtitle),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  hPad / 2,
                  0,
                  hPad / 2,
                  JtrResponsive.getResponsiveHeight(context, 24),
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: child,
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

class _BackHeader extends StatelessWidget {
  const _BackHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Get.back(),
        borderRadius: BorderRadius.circular(
          JtrResponsive.getResponsiveRadius(context, 8),
        ),
        child: Padding(
          padding: JtrResponsive.getResponsivePadding(
            context,
            vertical: 4,
          ),
          child: Row(
            children: [
              Icon(
                Icons.arrow_back_rounded,
                color: JtrMobileTheme.textSecondary,
                size: JtrResponsive.getResponsiveSize(context, 22),
              ),
              SizedBox(width: JtrResponsive.getResponsiveWidth(context, 8)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize:
                          JtrResponsive.getResponsiveFontSize(context, 15),
                      fontWeight: FontWeight.w600,
                      color: JtrMobileTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize:
                          JtrResponsive.getResponsiveFontSize(context, 12),
                      color: JtrMobileTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class JtrMobileExpansionCard extends StatelessWidget {
  const JtrMobileExpansionCard({
    super.key,
    required this.title,
    required this.trailing,
    required this.children,
    this.leading,
    this.initiallyExpanded = false,
  });

  final Widget title;
  final Widget trailing;
  final List<Widget> children;
  final Widget? leading;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final radius = JtrResponsive.getResponsiveRadius(context, 12);
    return Container(
      margin: EdgeInsets.only(
        bottom: JtrResponsive.getResponsiveHeight(context, 10),
      ),
      decoration: BoxDecoration(
        color: JtrMobileTheme.surfaceCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: JtrMobileTheme.border, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: JtrResponsive.getResponsivePadding(
            context,
            horizontal: 16,
            vertical: 0,
          ),
          childrenPadding: EdgeInsets.zero,
          leading: leading,
          title: title,
          trailing: trailing,
          iconColor: JtrMobileTheme.textMuted,
          collapsedIconColor: JtrMobileTheme.textMuted,
          children: children,
        ),
      ),
    );
  }
}

/// Footer note on gap detail lists.
class JtrMobileTxnFooterNote extends StatelessWidget {
  const JtrMobileTxnFooterNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: JtrResponsive.getResponsivePadding(
        context,
        horizontal: 16,
        vertical: 10,
      ),
      child: Text(
        'Aperçu des dernières opérations · liste complète exportable',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: JtrResponsive.getResponsiveFontSize(context, 11),
          color: JtrMobileTheme.textMuted,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/session_controller.dart';
import '../models/session_order.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';

/// Paid / closed orders for the active day — opened from Statistics.
class PaidOrdersPage extends GetView<SessionController> {
  const PaidOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.connectBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: AppTheme.darkText,
            size: JtrResponsive.getResponsiveSize(context, 20),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'COMMANDES PAYÉES',
          style: TextStyle(
            color: AppTheme.primary,
            fontSize: JtrResponsive.getResponsiveFontSize(context, 18),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Obx(() {
        final loading = controller.isLoadingPaidOrders.value;
        final orders = controller.paidOrders.toList();

        if (loading && orders.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        return Column(
          children: [
            if (loading)
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppTheme.primary,
                backgroundColor: Colors.transparent,
              ),
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primary,
                onRefresh: () => controller.loadPaidOrders(forceRefresh: true),
                child: orders.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.35,
                          ),
                          const _PaidEmptyState(),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: JtrResponsive.getResponsivePadding(
                          context,
                          horizontal: 20,
                          vertical: 24,
                        ),
                        itemCount: orders.length,
                        separatorBuilder: (_, _) =>
                            JtrResponsive.getResponsiveSpacing(context, 10),
                        itemBuilder: (context, index) =>
                            _PaidOrderRow(order: orders[index]),
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _PaidEmptyState extends StatelessWidget {
  const _PaidEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.payments_outlined,
            size: JtrResponsive.getResponsiveSize(context, 48),
            color: AppTheme.textSecondary.withValues(alpha: 0.45),
          ),
          JtrResponsive.getResponsiveSpacing(context, 12),
          Text(
            'Aucune commande payée',
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 14),
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaidOrderRow extends StatelessWidget {
  const _PaidOrderRow({required this.order});

  final SessionOrder order;

  @override
  Widget build(BuildContext context) {
    final badgeSize = JtrResponsive.getResponsiveSize(context, 40);

    return Container(
      padding: JtrResponsive.getResponsivePadding(
        context,
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(
          JtrResponsive.getResponsiveRadius(context, 12),
        ),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: JtrResponsive.getResponsiveSize(context, 4),
            offset: Offset(
              0,
              JtrResponsive.getResponsiveHeight(context, 1),
            ),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              color: const Color(0xFF5BAD6F).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(
                JtrResponsive.getResponsiveRadius(context, 10),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              order.number,
              style: TextStyle(
                fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
                fontWeight: FontWeight.bold,
                color: const Color(0xFF5BAD6F),
              ),
            ),
          ),
          JtrResponsive.getResponsiveHorizontalSpacing(context, 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order.itemCount} article${order.itemCount != 1 ? 's' : ''}  •  ${order.poste}',
                  style: TextStyle(
                    fontSize: JtrResponsive.getResponsiveFontSize(context, 12),
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
                JtrResponsive.getResponsiveSpacing(context, 2),
                Text(
                  order.profitCenter,
                  style: TextStyle(
                    fontSize: JtrResponsive.getResponsiveFontSize(context, 11),
                    fontWeight: FontWeight.w500,
                    color: AppTheme.darkText,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          JtrResponsive.getResponsiveHorizontalSpacing(context, 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                order.total,
                style: TextStyle(
                  fontSize: JtrResponsive.getResponsiveFontSize(context, 14),
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                ),
              ),
              JtrResponsive.getResponsiveSpacing(context, 4),
              Container(
                padding: JtrResponsive.getResponsivePadding(
                  context,
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF5BAD6F).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(
                    JtrResponsive.getResponsiveRadius(context, 8),
                  ),
                ),
                child: Text(
                  'PAYÉ',
                  style: TextStyle(
                    fontSize: JtrResponsive.getResponsiveFontSize(context, 9),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF5BAD6F),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

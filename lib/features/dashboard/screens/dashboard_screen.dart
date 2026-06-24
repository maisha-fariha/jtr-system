import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../data/dashboard_data.dart';
import '../models/table_order.dart';
import '../widgets/session_header.dart';
import '../widgets/order_table.dart';
import '../widgets/footer_action_buttons.dart';
import '../widgets/bottom_nav_bar.dart';

/// Main dashboard / order-management screen.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.role});

  final String? role;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _navIndex = 0;
  final ScrollController _scrollController = ScrollController();

  List<TableOrder> get _orders => DashboardData.orders;

  String get _roleLabel {
    final role = widget.role ?? AppStrings.manager;
    if (role == AppStrings.manager) {
      return AppStrings.roleLabelManager;
    }
    return role[0].toUpperCase() + role.substring(1).toLowerCase();
  }

  String get _formattedDate {
    return DateFormat('EEEE d MMMM yyyy', 'fr_FR')
        .format(DateTime.now())
        .toUpperCase();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SessionHeader(
                sessionNumber: 1,
                role: _roleLabel,
                date: _formattedDate,
                serviceType: AppStrings.surPlace,
              ),
              Expanded(
                child: OrderTable(
                  controller: _scrollController,
                  orders: _orders,
                  onRowTap: (order) => context.push(
                    AppRoutes.orderDetailPath(order.tableNumber),
                  ),
                ),
              ),
              FooterActionButtons(
                onNewOrder: () => context.push(AppRoutes.newOrder),
                onRequestNext: () => context.push(AppRoutes.requestNext),
                onTicket: () => context.push(AppRoutes.ticket),
                onStatistics: () => context.push(AppRoutes.statistics),
              ),
              DashboardBottomNavBar(
                currentIndex: _navIndex,
                onTap: _handleBottomNavTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleBottomNavTap(int index) {
    switch (index) {
      case 0:
        setState(() => _navIndex = 0);
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      case 1:
        _handleBackNavigation();
        setState(() => _navIndex = 0);
      case 2:
        _handleLogout();
    }
  }

  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
      return;
    }

    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showConfirmDialog(
      context: context,
      title: AppStrings.logoutTitle,
      message: AppStrings.logoutMessage,
      confirmLabel: AppStrings.exit,
    );

    if (shouldLogout && mounted) {
      context.go(AppRoutes.home);
    }
  }
}

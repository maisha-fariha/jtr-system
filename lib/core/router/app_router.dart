import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/auth/screens/connexion_screen.dart';
import '../../features/auth/screens/loading_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/dashboard/screens/order_detail_screen.dart';
import '../../features/dashboard/screens/new_order_screen.dart';
import '../../features/dashboard/screens/request_next_screen.dart';
import '../../features/dashboard/screens/ticket_screen.dart';
import '../../features/dashboard/screens/statistics_screen.dart';

abstract final class AppRoutes {
  static const String home = '/';
  static const String connexion = '/connexion';
  static const String loading = '/loading';
  static const String dashboard = '/dashboard';
  static const String newOrder = '/new-order';
  static const String requestNext = '/request-next';
  static const String ticket = '/ticket';
  static const String statistics = '/statistics';
  static const String orderDetail = '/order/:tableNumber';

  static String orderDetailPath(String tableNumber) => '/order/$tableNumber';

  static String requestNextPath([String? tableNumber]) {
    if (tableNumber == null || tableNumber.isEmpty) {
      return requestNext;
    }
    return '$requestNext?table=$tableNumber';
  }

  static String ticketPath([String? tableNumber]) {
    if (tableNumber == null || tableNumber.isEmpty) {
      return ticket;
    }
    return '$ticket?table=$tableNumber';
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      pageBuilder: (context, state) => const NoTransitionPage(
        child: HomeScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.connexion,
      pageBuilder: (context, state) => const MaterialPage(
        child: ConnexionScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.loading,
      pageBuilder: (context, state) => MaterialPage(
        child: LoadingScreen(
          role: state.uri.queryParameters['role'],
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.dashboard,
      pageBuilder: (context, state) => NoTransitionPage(
        child: DashboardScreen(
          role: state.uri.queryParameters['role'],
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.newOrder,
      pageBuilder: (context, state) => const MaterialPage(
        child: NewOrderScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.requestNext,
      pageBuilder: (context, state) => MaterialPage(
        child: RequestNextScreen(
          tableNumber: state.uri.queryParameters['table'],
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.ticket,
      pageBuilder: (context, state) => MaterialPage(
        child: TicketScreen(
          tableNumber: state.uri.queryParameters['table'],
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.statistics,
      pageBuilder: (context, state) => const MaterialPage(
        child: StatisticsScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.orderDetail,
      pageBuilder: (context, state) => MaterialPage(
        child: OrderDetailScreen(
          tableNumber: state.pathParameters['tableNumber']!,
        ),
      ),
    ),
  ],
);

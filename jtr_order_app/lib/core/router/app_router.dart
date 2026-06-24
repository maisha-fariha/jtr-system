import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/auth/screens/connexion_screen.dart';
import '../../features/auth/screens/loading_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';

abstract final class AppRoutes {
  static const String home = '/';
  static const String connexion = '/connexion';
  static const String loading = '/loading';
  static const String dashboard = '/dashboard';
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
      pageBuilder: (context, state) => const MaterialPage(
        child: LoadingScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.dashboard,
      pageBuilder: (context, state) => const NoTransitionPage(
        child: DashboardScreen(),
      ),
    ),
  ],
);

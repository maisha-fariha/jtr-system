import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/theme_controller.dart';
import '../data/dummy_dashboard_data.dart';
import '../models/dashboard_models.dart';

class JtrMobileDashboardController extends GetxController {
  final data = JtrMobileDummyData.dashboard().obs;
  final chatOpen = false.obs;
  final periodOpen = false.obs;
  final isRefreshing = false.obs;

  DateTime get periodFrom => data.value.periodFrom;
  DateTime get periodTo => data.value.periodTo;

  void toggleChat() => chatOpen.value = !chatOpen.value;

  void togglePeriod() => periodOpen.value = !periodOpen.value;

  void toggleTheme() => ThemeController.to.toggle();

  void onGapDetailTap() {
    Get.snackbar(
      'JTR Mobile',
      'Détail de l\'écart — à venir',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    );
  }

  void onFamilyDetailTap() {
    Get.snackbar(
      'JTR Mobile',
      'Ventes par famille — à venir',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> applyPeriod(DateTime from, DateTime to) async {
    isRefreshing.value = true;
    periodOpen.value = false;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final current = data.value;
    data.value = JtrDashboardData(
      storeName: current.storeName,
      dateLabel: current.dateLabel,
      periodLabel: _formatPeriodLabel(from, to),
      kpis: current.kpis,
      payments: current.payments,
      gapSegments: current.gapSegments,
      gapTotal: current.gapTotal,
      categories: current.categories,
      zones: current.zones,
      activity: current.activity,
      movements: current.movements,
      hourlyBars: current.hourlyBars,
      peakCaption: current.peakCaption,
      periodFrom: from,
      periodTo: to,
    );
    isRefreshing.value = false;
  }

  Future<void> refreshDashboard() async {
    isRefreshing.value = true;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    data.value = JtrMobileDummyData.dashboard();
    isRefreshing.value = false;
  }

  static String _formatPeriodLabel(DateTime from, DateTime to) {
    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    if (from.year == to.year && from.month == to.month) {
      return '${months[from.month - 1]} ${from.year}';
    }
    return '${from.day}/${from.month} – ${to.day}/${to.month} ${to.year}';
  }
}

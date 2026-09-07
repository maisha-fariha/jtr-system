import 'dart:async';

import 'package:get/get.dart';

import '../../controllers/theme_controller.dart';
import '../../core/network/api_exception.dart';
import '../../utils/app_snackbar.dart';
import '../data/jtr_mobile_dashboard_filters.dart';
import '../data/repositories/jtr_mobile_dashboard_repository.dart';
import '../models/dashboard_models.dart';
import '../models/detail_models.dart';
import '../pages/jtr_mobile_family_sales_page.dart';
import '../pages/jtr_mobile_gap_detail_page.dart';

class JtrMobileDashboardController extends GetxController {
  JtrMobileDashboardController({
    required JtrMobileDashboardRepository repository,
  }) : _repository = repository;

  final JtrMobileDashboardRepository _repository;

  final data = Rxn<JtrDashboardData>();
  final productFamilies = <JtrProductFamily>[].obs;
  final gapCategories = <JtrGapCategoryDetail>[].obs;

  final chatOpen = false.obs;
  final periodOpen = false.obs;
  final isLoading = false.obs;
  final isRefreshing = false.obs;
  final isFamiliesLoading = false.obs;
  final isGapLoading = false.obs;

  JtrMobileDashboardFilters? _filters;

  DateTime get periodFrom =>
      _filters?.dateFrom ?? data.value?.periodFrom ?? DateTime.now();
  DateTime get periodTo =>
      _filters?.dateTo ?? data.value?.periodTo ?? DateTime.now();

  @override
  void onInit() {
    super.onInit();
    unawaited(_loadInitial());
  }

  Future<void> _loadInitial() async {
    isLoading.value = true;
    try {
      _filters = await _repository.resolveDefaultFilters();
      data.value = await _repository.fetchDashboard(filters: _filters!);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Impossible de charger le tableau de bord.');
    } finally {
      isLoading.value = false;
    }
  }

  JtrMobileDashboardFilters _currentFilters() {
    return _filters ??
        JtrMobileDashboardFilters(
          dateFrom: periodFrom,
          dateTo: periodTo,
        );
  }

  void toggleChat() => chatOpen.value = !chatOpen.value;

  void togglePeriod() => periodOpen.value = !periodOpen.value;

  void toggleTheme() => ThemeController.to.toggle();

  Future<void> onGapDetailTap() async {
    await Get.to(() => const JtrMobileGapDetailPage());
  }

  Future<void> onFamilyDetailTap() async {
    await Get.to(() => const JtrMobileFamilySalesPage());
  }

  Future<void> applyPeriod(DateTime from, DateTime to) async {
    periodOpen.value = false;
    _filters = JtrMobileDashboardFilters(
      dateFrom: DateTime(from.year, from.month, from.day),
      dateTo: DateTime(to.year, to.month, to.day),
    );
    await refreshDashboard();
  }

  Future<void> refreshDashboard() async {
    if (isRefreshing.value) return;
    final showFullLoader = data.value == null;
    if (showFullLoader) isLoading.value = true;
    isRefreshing.value = true;
    try {
      _filters ??= await _repository.resolveDefaultFilters();
      final filters = _currentFilters();
      data.value = await _repository.fetchDashboard(filters: filters);
      _filters = filters;
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Impossible de rafraîchir le tableau de bord.');
    } finally {
      isRefreshing.value = false;
      if (showFullLoader) isLoading.value = false;
    }
  }

  Future<void> loadProductFamilies() async {
    isFamiliesLoading.value = true;
    productFamilies.clear();
    try {
      final families = await _repository.fetchProductFamilies(
        filters: _currentFilters(),
      );
      productFamilies.assignAll(families);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Impossible de charger les ventes par famille.');
    } finally {
      isFamiliesLoading.value = false;
    }
  }

  Future<void> loadGapCategories() async {
    isGapLoading.value = true;
    gapCategories.clear();
    try {
      final categories = await _repository.fetchGapCategories(
        filters: _currentFilters(),
      );
      gapCategories.assignAll(categories);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError("Impossible de charger le détail de l'écart.");
    } finally {
      isGapLoading.value = false;
    }
  }

  void _showError(String message) {
    AppSnackbar.show('Tableau de bord', message);
  }
}

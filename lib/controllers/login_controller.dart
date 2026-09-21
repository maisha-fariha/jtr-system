import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/session_controller.dart';
import '../core/app_flavor.dart';
import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/storage/device_secure_storage.dart';
import '../data/models/device_activation_models.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/device_repository.dart';
import '../data/repositories/session_repository.dart';
import '../jtr_mobile/assistant/jtr_mobile_assistant_controller.dart';
import '../jtr_mobile/controllers/jtr_mobile_dashboard_controller.dart';
import '../jtr_mobile/data/jtr_mobile_dashboard_remote_datasource.dart';
import '../jtr_mobile/data/repositories/jtr_mobile_dashboard_repository.dart';
import '../jtr_mobile/restaurants/rapport_restaurant_store.dart';
import '../jtr_mobile/restaurants/rapport_saved_restaurant.dart';
import '../models/user_suggestion.dart';
import '../routes/app_pages.dart';
import '../services/reverb_realtime_service.dart';
import '../utils/app_navigation.dart';
import '../utils/app_snackbar.dart';
import '../widgets/user_identifiant_field_controller.dart';

class LoginController extends GetxController {
  LoginController({required AuthRepository authRepository})
      : _authRepository = authRepository;

  final AuthRepository _authRepository;

  final identifiantController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordFocusNode = FocusNode();
  final obscurePassword = true.obs;
  final selectedUser = Rxn<UserSuggestion>();
  final isLoading = false.obs;
  final isLoadingUsers = false.obs;
  final users = <UserSuggestion>[].obs;
  final roles = <String>[].obs;

  /// Rapport only — saved restaurants for multi-tenant switch.
  final restaurants = <RapportSavedRestaurant>[].obs;
  final selectedRestaurantId = RxnString();
  final isSwitchingRestaurant = false.obs;

  late final UserIdentifiantFieldController identifiantFieldController;

  bool get showRestaurantSwitcher => AppFlavorConfig.isRapport;

  RapportSavedRestaurant? get selectedRestaurant {
    final id = selectedRestaurantId.value;
    if (id == null) return null;
    for (final r in restaurants) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  void onInit() {
    super.onInit();
    identifiantFieldController = UserIdentifiantFieldController(
      textController: identifiantController,
      hideSuggestionsFocusNode: passwordFocusNode,
      initialUsers: const [],
    );
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    if (showRestaurantSwitcher) {
      await _loadRestaurants();
    }
    await _loadAuthData();
  }

  Future<void> _loadRestaurants() async {
    if (!Get.isRegistered<RapportRestaurantStore>() ||
        !Get.isRegistered<DeviceRepository>()) {
      return;
    }
    final store = Get.find<RapportRestaurantStore>();
    final deviceRepo = Get.find<DeviceRepository>();
    final active = await deviceRepo.readStoredCredentials();
    await store.ensureSeededFromActive(active);

    final list = await store.readAll();
    restaurants.assignAll(list);

    var selectedId = await store.readSelectedId();
    if (selectedId == null ||
        selectedId.isEmpty ||
        !list.any((r) => r.id == selectedId)) {
      if (active != null) {
        selectedId = RapportSavedRestaurant.fromCredentials(active).id;
      } else if (list.isNotEmpty) {
        selectedId = list.first.id;
      }
    }
    selectedRestaurantId.value = selectedId;
  }

  Future<void> _loadAuthData() async {
    isLoadingUsers.value = true;
    try {
      final loadedUsers = await _authRepository.getLoginUsers(
        forceRefresh: true,
      );
      users.assignAll(loadedUsers);
      identifiantFieldController.updateUsers(loadedUsers);

      final loadedRoles = await _authRepository.getLoginRoles(
        forceRefresh: true,
      );
      roles.assignAll(loadedRoles.map((role) => role.name));
    } on ApiException catch (error) {
      if (showRestaurantSwitcher) {
        // Never fall back to another restaurant's cached users on Rapport.
        users.clear();
        identifiantFieldController.updateUsers(const []);
        roles.clear();
        AppSnackbar.show(
          'Erreur',
          error.message,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
        );
      } else {
        final cached = _authRepository.cachedUserSuggestions;
        if (cached.isNotEmpty) {
          users.assignAll(cached);
          identifiantFieldController.updateUsers(cached);
        } else {
          AppSnackbar.show(
            'Erreur',
            error.message,
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(16),
          );
        }
      }
    } finally {
      isLoadingUsers.value = false;
    }
  }

  /// Apply a saved restaurant as the active tenant and reload login users.
  Future<void> selectRestaurant(RapportSavedRestaurant restaurant) async {
    if (!showRestaurantSwitcher || isSwitchingRestaurant.value) return;
    if (selectedRestaurantId.value == restaurant.id) return;

    isSwitchingRestaurant.value = true;
    try {
      await _clearTenantScopedState();

      if (!Get.isRegistered<DeviceSecureStorage>() ||
          !Get.isRegistered<DeviceRepository>() ||
          !Get.isRegistered<ApiClient>() ||
          !Get.isRegistered<RapportRestaurantStore>()) {
        return;
      }

      final creds = restaurant.toCredentials();
      await Get.find<DeviceSecureStorage>().saveCredentials(creds);
      await Get.find<RapportRestaurantStore>().upsertAndSelect(restaurant);

      ApiConfig.applyRuntime(
        baseUrl: creds.apiBaseUrl,
        tenantSchema: creds.tenantSchema,
        deviceId: creds.deviceId,
        deviceToken: creds.deviceToken,
      );
      Get.find<DeviceRepository>().applyRuntimeConfigOnly();
      Get.find<ApiClient>().setAuthToken(null);

      selectedRestaurantId.value = restaurant.id;
      if (!restaurants.any((r) => r.id == restaurant.id)) {
        restaurants.add(restaurant);
      }

      selectedUser.value = null;
      identifiantController.clear();
      passwordController.clear();

      await _loadAuthData();
    } on ApiException catch (e) {
      AppSnackbar.show(
        'Restaurant',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      AppSnackbar.show(
        'Restaurant',
        'Impossible de changer de restaurant.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } finally {
      isSwitchingRestaurant.value = false;
    }
  }

  /// Scan / activate another restaurant without wiping the saved list.
  Future<void> addRestaurantByScan() async {
    if (!showRestaurantSwitcher) return;
    try {
      await _authRepository.clearTenantScopedAuthCache();
    } catch (_) {}
    _disposeRapportScopedControllers();
    // Replace login in the stack so activation → offAllNamed(login) cannot
    // dispose a LoginController still owned by an underlying LoginPage.
    AppNavigation.ensureLoginControllerForNavigation(recreate: false);
    await Get.offNamed(
      AppRoutes.activation,
      arguments: const {'returnToLogin': true},
    );
  }

  Future<void> _clearTenantScopedState() async {
    if (Get.isRegistered<ReverbRealtimeService>()) {
      try {
        await Get.find<ReverbRealtimeService>()
            .stop()
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    await _authRepository.clearTenantScopedAuthCache();
    if (Get.isRegistered<SessionRepository>()) {
      try {
        await Get.find<SessionRepository>().clearOpenOrdersCache();
      } catch (_) {}
    }
    _disposeRapportScopedControllers();
  }

  void _disposeRapportScopedControllers() {
    if (Get.isRegistered<JtrMobileAssistantController>()) {
      Get.delete<JtrMobileAssistantController>(force: true);
    }
    if (Get.isRegistered<JtrMobileDashboardController>()) {
      Get.delete<JtrMobileDashboardController>(force: true);
    }
    if (Get.isRegistered<JtrMobileDashboardRepository>()) {
      Get.delete<JtrMobileDashboardRepository>(force: true);
    }
    if (Get.isRegistered<JtrMobileDashboardRemoteDataSource>()) {
      Get.delete<JtrMobileDashboardRemoteDataSource>(force: true);
    }
  }

  @override
  void onClose() {
    identifiantFieldController.dispose();
    identifiantController.dispose();
    passwordController.dispose();
    passwordFocusNode.dispose();
    super.onClose();
  }

  void selectUser(UserSuggestion user) {
    selectedUser.value = user;
  }

  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }

  Future<void> login() async {
    if (isLoading.value) return;

    final user = selectedUser.value ?? _resolveUserFromText();
    if (user == null) {
      AppSnackbar.show(
        'Identifiant requis',
        'Veuillez sélectionner un utilisateur.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    final passcode = passwordController.text.trim();
    if (passcode.isEmpty) {
      AppSnackbar.show(
        'Code requis',
        'Veuillez saisir votre mot de passe.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    isLoading.value = true;
    try {
      final deviceBlock = await _deviceDeactivationMessage();
      if (deviceBlock != null) {
        _showLoginError(deviceBlock.title, deviceBlock.message);
        return;
      }

      final userBlock = _inactiveUserMessage(user.id);
      if (userBlock != null) {
        _showLoginError('Compte désactivé', userBlock);
        return;
      }

      final session = await _authRepository.login(
        userOrId: user.id,
        passcode: passcode,
      );

      if (session.user.isActive == false) {
        await _authRepository.logout();
        _showLoginError(
          'Compte désactivé',
          'Cet utilisateur a été désactivé. Connexion impossible.',
        );
        return;
      }

      final deviceBlockAfter = await _deviceDeactivationMessage();
      if (deviceBlockAfter != null) {
        await _authRepository.logout();
        _showLoginError(deviceBlockAfter.title, deviceBlockAfter.message);
        return;
      }

      if (Get.isRegistered<SessionRepository>()) {
        await Get.find<SessionRepository>().clearOpenOrdersCache();
      }
      if (Get.isRegistered<SessionController>()) {
        Get.delete<SessionController>(force: true);
      }
      if (Get.isRegistered<ReverbRealtimeService>()) {
        unawaited(Get.find<ReverbRealtimeService>().start());
      }
      if (AppFlavorConfig.isRapport) {
        Get.offAllNamed(AppRoutes.jtrMobileDashboard);
      } else {
        Get.offNamed(AppRoutes.connect);
      }
    } on ApiException catch (error) {
      final deactivated = _deactivationMessageFromApi(error.message);
      if (deactivated != null) {
        try {
          await _authRepository.logout();
        } catch (_) {}
        _showLoginError(deactivated.title, deactivated.message);
        return;
      }
      _showLoginError('Connexion échouée', error.message);
    } finally {
      isLoading.value = false;
    }
  }

  void _showLoginError(String title, String message) {
    AppSnackbar.show(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
    );
  }

  Future<({String title, String message})?> _deviceDeactivationMessage() async {
    if (!Get.isRegistered<DeviceRepository>()) return null;
    try {
      final outcome =
          await Get.find<DeviceRepository>().resolveStartupGate();
      switch (outcome) {
        case DeviceGateOutcome.deactivated:
          return (
            title: 'Poste désactivé',
            message:
                'Ce poste a été désactivé depuis le dashboard. Connexion impossible.',
          );
        case DeviceGateOutcome.licenseBlocked:
          return (
            title: 'Licence invalide',
            message:
                'La licence de cet établissement est expirée ou invalide. Connexion impossible.',
          );
        case DeviceGateOutcome.needsActivation:
          return (
            title: 'Poste non activé',
            message:
                'Ce poste n\'est plus activé. Veuillez réactiver le dispositif.',
          );
        case DeviceGateOutcome.active:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  String? _inactiveUserMessage(String userId) {
    final id = int.tryParse(userId);
    for (final u in _authRepository.cachedUsers) {
      final matches = (id != null && u.id == id) ||
          u.id.toString() == userId ||
          (u.username != null &&
              u.username!.toLowerCase() == userId.toLowerCase());
      if (!matches) continue;
      if (u.isActive == false) {
        return 'Cet utilisateur a été désactivé. Connexion impossible.';
      }
      return null;
    }
    return null;
  }

  ({String title, String message})? _deactivationMessageFromApi(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('deactivated') ||
        lower.contains('désactivé') ||
        lower.contains('desactive') ||
        lower.contains('disabled')) {
      if (lower.contains('device') ||
          lower.contains('poste') ||
          lower.contains('terminal')) {
        return (
          title: 'Poste désactivé',
          message:
              'Ce poste a été désactivé depuis le dashboard. Connexion impossible.',
        );
      }
      return (
        title: 'Compte désactivé',
        message: raw.trim().isNotEmpty
            ? raw.trim()
            : 'Cet utilisateur a été désactivé. Connexion impossible.',
      );
    }
    if (lower.contains('license') ||
        lower.contains('licence') ||
        lower.contains('expired')) {
      return (
        title: 'Licence invalide',
        message: raw.trim().isNotEmpty
            ? raw.trim()
            : 'La licence de cet établissement est invalide. Connexion impossible.',
      );
    }
    return null;
  }

  UserSuggestion? _resolveUserFromText() {
    final query = identifiantController.text.trim().toLowerCase();
    if (query.isEmpty) return null;

    for (final user in users) {
      if (user.id == query ||
          user.name.toLowerCase() == query ||
          user.name.toLowerCase().contains(query)) {
        return user;
      }
    }
    return null;
  }
}

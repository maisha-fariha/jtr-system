import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/network/api_exception.dart';
import '../data/models/device_activation_models.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/device_repository.dart';
import '../data/repositories/session_repository.dart';
import '../controllers/session_controller.dart';
import '../models/user_suggestion.dart';
import '../routes/app_pages.dart';
import '../services/reverb_realtime_service.dart';
import '../widgets/user_identifiant_field_controller.dart';
import '../utils/app_snackbar.dart';

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

  late final UserIdentifiantFieldController identifiantFieldController;

  @override
  void onInit() {
    super.onInit();
    // Never seed stale/dummy cache into the field — always wait for a fresh
    // fetch (or an explicit cache fallback if offline).
    identifiantFieldController = UserIdentifiantFieldController(
      textController: identifiantController,
      hideSuggestionsFocusNode: passwordFocusNode,
      initialUsers: const [],
    );
    unawaited(_loadAuthData());
  }

  Future<void> _loadAuthData() async {
    isLoadingUsers.value = true;
    try {
      // Always hit the network after device activate / logout so the picker
      // is not stuck on a previous session's cached (or dummy) users.
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
    } finally {
      isLoadingUsers.value = false;
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
      // Block on login screen — never enter Connect/Session when deactivated.
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

      // API may still return a token for a deactivated user — reject here.
      if (session.user.isActive == false) {
        await _authRepository.logout();
        _showLoginError(
          'Compte désactivé',
          'Cet utilisateur a été désactivé. Connexion impossible.',
        );
        return;
      }

      // Re-check device after login (headers/token now fully set).
      final deviceBlockAfter = await _deviceDeactivationMessage();
      if (deviceBlockAfter != null) {
        await _authRepository.logout();
        _showLoginError(deviceBlockAfter.title, deviceBlockAfter.message);
        return;
      }

      if (Get.isRegistered<SessionRepository>()) {
        await Get.find<SessionRepository>().clearOpenOrdersCache();
      }
      // Drop any previous session controller so the next open is a fresh paint.
      if (Get.isRegistered<SessionController>()) {
        Get.delete<SessionController>(force: true);
      }
      // Connect Reverb after Sanctum + device headers are ready.
      if (Get.isRegistered<ReverbRealtimeService>()) {
        unawaited(Get.find<ReverbRealtimeService>().start());
      }
      // Auth succeeded — reuse the existing "Chargement base de données"
      // screen to preload session data before the session page mounts.
      Get.offNamed(AppRoutes.connect);
    } on ApiException catch (error) {
      final deactivated = _deactivationMessageFromApi(error.message);
      if (deactivated != null) {
        // Ensure no partial session stays after a rejected login.
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

  /// Device/poste deactivated or license blocked — stay on login.
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
      // Network blip: do not block login solely on gate failure.
      return null;
    }
  }

  /// User marked inactive in the login-users list.
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

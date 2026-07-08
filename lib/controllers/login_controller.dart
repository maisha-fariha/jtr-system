import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/network/api_exception.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/session_repository.dart';
import '../models/user_suggestion.dart';
import '../routes/app_pages.dart';
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

  late final UserIdentifiantFieldController identifiantFieldController;

  @override
  void onInit() {
    super.onInit();
    identifiantFieldController = UserIdentifiantFieldController(
      textController: identifiantController,
      hideSuggestionsFocusNode: passwordFocusNode,
      initialUsers: _authRepository.cachedUserSuggestions,
    );
    _loadAuthData();
  }

  Future<void> _loadAuthData() async {
    isLoadingUsers.value = true;
    try {
      final loadedUsers = await _authRepository.getLoginUsers();
      users.assignAll(loadedUsers);
      identifiantFieldController.updateUsers(loadedUsers);

      final loadedRoles = await _authRepository.getLoginRoles();
      roles.assignAll(loadedRoles.map((role) => role.name));
    } on ApiException catch (error) {
      final cached = _authRepository.cachedUserSuggestions;
      if (cached.isNotEmpty) {
        users.assignAll(cached);
        identifiantFieldController.updateUsers(cached);
      } else {
        Get.snackbar(
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
      Get.snackbar(
        'Identifiant requis',
        'Veuillez sélectionner un utilisateur.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    final passcode = passwordController.text.trim();
    if (passcode.isEmpty) {
      Get.snackbar(
        'Code requis',
        'Veuillez saisir votre mot de passe.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    isLoading.value = true;
    try {
      await _authRepository.login(
        userOrId: user.id,
        passcode: passcode,
      );
      if (Get.isRegistered<SessionRepository>()) {
        await Get.find<SessionRepository>().clearOpenOrdersCache();
      }
      Get.offNamed(AppRoutes.session);
    } on ApiException catch (error) {
      Get.snackbar(
        'Connexion échouée',
        error.message,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } finally {
      isLoading.value = false;
    }
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

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/user_suggestion.dart';
import '../widgets/user_identifiant_field_controller.dart';

class LoginController extends GetxController {
  final identifiantController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordFocusNode = FocusNode();
  final obscurePassword = true.obs;
  final selectedUser = Rxn<UserSuggestion>();
  late final UserIdentifiantFieldController identifiantFieldController;

  @override
  void onInit() {
    super.onInit();
    identifiantFieldController = UserIdentifiantFieldController(
      textController: identifiantController,
      hideSuggestionsFocusNode: passwordFocusNode,
    );
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
}

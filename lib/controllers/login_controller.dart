import 'package:get/get.dart';
import '../models/user_suggestion.dart';
import '../routes/app_routes.dart';
import '../widgets/user_identifiant_field_controller.dart';

class LoginController extends GetxController {
  late final UserIdentifiantFieldController identifiantFieldController;
  final obscurePassword = true.obs;

  @override
  void onInit() {
    super.onInit();
    identifiantFieldController = UserIdentifiantFieldController();
  }

  @override
  void onClose() {
    identifiantFieldController.dispose();
    super.onClose();
  }

  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }

  void selectUser(UserSuggestion user) {
    identifiantFieldController.selectUser(user);
  }

  void login() {
    Get.offNamed(AppRoutes.session);
  }
}

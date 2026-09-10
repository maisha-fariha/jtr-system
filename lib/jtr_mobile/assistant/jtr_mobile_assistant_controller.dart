import 'package:get/get.dart';

import '../controllers/jtr_mobile_dashboard_controller.dart';
import '../models/dashboard_models.dart';
import 'jtr_mobile_assistant_message.dart';
import 'jtr_mobile_dummy_assistant.dart';

/// TEMPORARY chat state for the dummy assistant.
///
/// Safe to delete with the `assistant/` folder when the backend API is ready.
class JtrMobileAssistantController extends GetxController {
  JtrMobileAssistantController({
    JtrMobileDummyAssistant? assistant,
  }) : _assistant = assistant ?? const JtrMobileDummyAssistant();

  final JtrMobileDummyAssistant _assistant;

  final messages = <JtrMobileAssistantMessage>[
    const JtrMobileAssistantMessage(
      text: JtrMobileDummyAssistant.welcomeText,
      isUser: false,
    ),
  ].obs;

  final isReplying = false.obs;
  final inputText = ''.obs;

  Future<void> send([String? override]) async {
    final text = (override ?? inputText.value).trim();
    if (text.isEmpty || isReplying.value) return;

    inputText.value = '';
    messages.add(JtrMobileAssistantMessage(text: text, isUser: true));
    isReplying.value = true;

    try {
      JtrDashboardData? data;
      if (Get.isRegistered<JtrMobileDashboardController>()) {
        data = Get.find<JtrMobileDashboardController>().data.value;
      }
      final reply = await _assistant.reply(
        userMessage: text,
        data: data,
      );
      if (isClosed) return;
      messages.add(JtrMobileAssistantMessage(text: reply, isUser: false));
    } catch (_) {
      if (isClosed) return;
      messages.add(
        const JtrMobileAssistantMessage(
          text: 'Désolé, une erreur est survenue (mode démo).',
          isUser: false,
        ),
      );
    } finally {
      if (!isClosed) isReplying.value = false;
    }
  }
}

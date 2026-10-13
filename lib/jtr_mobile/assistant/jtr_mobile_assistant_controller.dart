import 'package:get/get.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import 'jtr_mobile_assistant_message.dart';
import 'jtr_mobile_chat_remote_datasource.dart';

/// Rapport dashboard chat — talks to `POST /api/chat` only.
///
/// Isolated from POS order/session controllers.
class JtrMobileAssistantController extends GetxController {
  JtrMobileAssistantController({
    JtrMobileChatRemoteDataSource? remote,
  }) : _remote = remote ??
            JtrMobileChatRemoteDataSource(Get.find<ApiClient>());

  final JtrMobileChatRemoteDataSource _remote;

  static const welcomeText =
      'Bonjour 👋 Posez une question sur vos ventes, stocks, '
      'commandes ou statistiques du jour.\n\n'
      'FR / EN / Darija — conversation mémorisée jusqu\'à '
      '« Nouvelle conversation ».';

  final messages = <JtrMobileAssistantMessage>[
    const JtrMobileAssistantMessage(
      text: welcomeText,
      isUser: false,
    ),
  ].obs;

  final isReplying = false.obs;
  final inputText = ''.obs;

  /// Backend conversation UUID — null starts a new thread.
  String? _conversationId;

  String? get conversationId => _conversationId;

  /// Clears history + conversation id (New Chat).
  void startNewConversation() {
    if (isReplying.value) return;
    _conversationId = null;
    inputText.value = '';
    messages
      ..clear()
      ..add(
        const JtrMobileAssistantMessage(
          text: welcomeText,
          isUser: false,
        ),
      );
  }

  Future<void> send([String? override]) async {
    final text = (override ?? inputText.value).trim();
    if (text.isEmpty || isReplying.value) return;

    inputText.value = '';
    messages.add(JtrMobileAssistantMessage(text: text, isUser: true));
    isReplying.value = true;

    try {
      final result = await _remote.sendMessage(
        message: text,
        conversationId: _conversationId,
        localeHint: 'auto',
      );
      if (isClosed) return;

      if (result.conversationId.isNotEmpty) {
        _conversationId = result.conversationId;
      }

      messages.add(
        JtrMobileAssistantMessage(
          text: result.reply,
          isUser: false,
          responseStatus: result.responseStatus,
        ),
      );
    } on ApiException catch (e) {
      if (isClosed) return;
      messages.add(
        JtrMobileAssistantMessage(
          text: _userFacingError(e),
          isUser: false,
          responseStatus: 'error',
        ),
      );
    } catch (_) {
      if (isClosed) return;
      messages.add(
        const JtrMobileAssistantMessage(
          text: 'Désolé, une erreur est survenue. Réessayez.',
          isUser: false,
          responseStatus: 'error',
        ),
      );
    } finally {
      if (!isClosed) isReplying.value = false;
    }
  }

  String _userFacingError(ApiException e) {
    if (e.statusCode == 403) {
      return 'Accès refusé : permission « access-pos-chat » requise '
          'pour utiliser l\'assistant.';
    }
    if (e.statusCode == 401) {
      return 'Session expirée. Reconnectez-vous puis réessayez.';
    }
    final msg = e.message.trim();
    if (msg.isNotEmpty) return msg;
    return 'Impossible de contacter l\'assistant. Vérifiez la connexion.';
  }
}

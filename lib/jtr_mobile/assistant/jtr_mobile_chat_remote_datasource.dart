import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/api_envelope.dart';
import 'jtr_mobile_chat_models.dart';

/// Isolated chat API client for JTR Rapport — does not touch POS order flows.
class JtrMobileChatRemoteDataSource {
  JtrMobileChatRemoteDataSource(this._client);

  final ApiClient _client;

  static const maxMessageLength = 2000;

  Future<JtrMobileChatReply> sendMessage({
    required String message,
    String? conversationId,
    String localeHint = 'auto',
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw ApiException(message: 'Message vide.');
    }
    if (trimmed.length > maxMessageLength) {
      throw ApiException(
        message:
            'Message trop long (max $maxMessageLength caractères).',
      );
    }

    final body = <String, dynamic>{
      'message': trimmed,
      'locale_hint': localeHint,
      'conversation_id':
          (conversationId != null && conversationId.isNotEmpty)
              ? conversationId
              : null,
    };

    _logRequest(body);

    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.chat,
      data: body,
    );

    final json = response.data;
    if (json == null) {
      throw ApiException(message: 'Réponse chat vide.');
    }

    final envelope = ApiEnvelope<dynamic>.fromJson(json, (v) => v);
    if (!envelope.success) {
      throw ApiException(
        message: envelope.message ?? 'Erreur assistant IA.',
        statusCode: envelope.status,
      );
    }

    final raw = envelope.data;
    if (raw is! Map) {
      throw ApiException(message: 'Réponse chat invalide.');
    }

    final reply = JtrMobileChatReply.fromJson(Map<String, dynamic>.from(raw));
    if (reply.reply.trim().isEmpty) {
      throw ApiException(message: 'Réponse chat sans texte.');
    }
    return reply;
  }

  void _logRequest(Map<String, dynamic> body) {
    final safe = Map<String, dynamic>.from(body);
    final msg = safe['message']?.toString() ?? '';
    if (msg.length > 80) {
      safe['message'] = '${msg.substring(0, 80)}…';
    }
    final buffer = StringBuffer()
      ..writeln('════════ JTR MOBILE CHAT REQUEST ════════')
      ..writeln('METHOD: POST')
      ..writeln('PATH: ${ApiEndpoints.chat}')
      ..writeln('BODY:')
      ..writeln(safe);
    final line = buffer.toString();
    // ignore: avoid_print
    print(line);
    debugPrint(line);
  }
}

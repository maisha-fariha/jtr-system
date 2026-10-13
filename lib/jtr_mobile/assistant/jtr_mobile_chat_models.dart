/// Response payload from `POST /api/chat` (`data` envelope field).
class JtrMobileChatReply {
  const JtrMobileChatReply({
    required this.conversationId,
    required this.reply,
    required this.responseStatus,
    this.language,
    this.rejectReason,
    this.toolsUsed = const [],
    this.sqlUsed = false,
    this.data,
  });

  final String conversationId;
  final String reply;

  /// `answered` | `rejected` | `unanswered`
  final String responseStatus;
  final String? language;
  final String? rejectReason;
  final List<String> toolsUsed;
  final bool sqlUsed;
  final Map<String, dynamic>? data;

  bool get isRejected => responseStatus == 'rejected';
  bool get isUnanswered => responseStatus == 'unanswered';

  factory JtrMobileChatReply.fromJson(Map<String, dynamic> json) {
    final tools = json['tools_used'];
    return JtrMobileChatReply(
      conversationId: json['conversation_id']?.toString() ?? '',
      reply: json['reply']?.toString() ?? '',
      responseStatus: json['response_status']?.toString() ?? 'answered',
      language: json['language']?.toString(),
      rejectReason: json['reject_reason']?.toString(),
      toolsUsed: tools is List
          ? tools.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : const [],
      sqlUsed: json['sql_used'] == true,
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
    );
  }
}

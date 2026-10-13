/// One bubble in the Rapport assistant chat UI.
class JtrMobileAssistantMessage {
  const JtrMobileAssistantMessage({
    required this.text,
    required this.isUser,
    this.responseStatus,
  });

  final String text;
  final bool isUser;

  /// From API: `answered` | `rejected` | `unanswered`, or `error` for client failures.
  final String? responseStatus;

  bool get isSoftRefusal => responseStatus == 'rejected';
}

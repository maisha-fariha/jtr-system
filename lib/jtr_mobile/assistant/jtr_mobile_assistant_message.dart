/// One bubble in the temporary chat UI.
class JtrMobileAssistantMessage {
  const JtrMobileAssistantMessage({
    required this.text,
    required this.isUser,
  });

  final String text;
  final bool isUser;
}

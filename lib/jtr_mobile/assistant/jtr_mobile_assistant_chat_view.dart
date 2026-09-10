import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../utils/responsive.dart';
import '../theme/jtr_mobile_theme.dart';
import 'jtr_mobile_assistant_controller.dart';
import 'jtr_mobile_assistant_message.dart';

/// Shared chat body (messages + input) for panel and full-screen page.
///
/// TEMPORARY mock UI — remove with `assistant/` when backend API is ready.
class JtrMobileAssistantChatView extends StatefulWidget {
  const JtrMobileAssistantChatView({
    super.key,
    this.expanded = false,
    this.padding,
  });

  /// When true, messages fill available height (full-screen page).
  final bool expanded;
  final EdgeInsetsGeometry? padding;

  @override
  State<JtrMobileAssistantChatView> createState() =>
      _JtrMobileAssistantChatViewState();
}

class _JtrMobileAssistantChatViewState
    extends State<JtrMobileAssistantChatView> {
  late final JtrMobileAssistantController _assistant;
  late final TextEditingController _input;
  late final FocusNode _focus;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _assistant = Get.isRegistered<JtrMobileAssistantController>()
        ? Get.find<JtrMobileAssistantController>()
        : Get.put(JtrMobileAssistantController());
    _input = TextEditingController(text: _assistant.inputText.value);
    _focus = FocusNode();
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    _assistant.inputText.value = '';
    _scrollToEnd();
    _assistant.send(text).then((_) {
      if (mounted) _scrollToEnd();
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = Obx(() {
      final items = _assistant.messages.toList();
      final replying = _assistant.isReplying.value;
      return ListView.builder(
        controller: _scroll,
        padding: widget.padding ??
            JtrResponsive.getResponsivePadding(
              context,
              horizontal: 14,
              vertical: 12,
            ),
        itemCount: items.length + (replying ? 1 : 0),
        itemBuilder: (context, index) {
          if (replying && index == items.length) {
            return const _TypingBubble();
          }
          return Padding(
            padding: EdgeInsets.only(
              bottom: JtrResponsive.getResponsiveHeight(context, 8),
            ),
            child: _MessageBubble(message: items[index]),
          );
        },
      );
    });

    final input = Padding(
      padding: JtrResponsive.getResponsivePadding(
        context,
        horizontal: 14,
        vertical: 0,
      ).copyWith(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              focusNode: _focus,
              textInputAction: TextInputAction.send,
              minLines: 1,
              maxLines: widget.expanded ? 4 : 2,
              onChanged: (v) => _assistant.inputText.value = v,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Écrivez votre question...',
                hintStyle: TextStyle(
                  fontSize: JtrResponsive.getResponsiveFontSize(context, 12),
                  color: JtrMobileTheme.textMuted,
                ),
                filled: true,
                fillColor: JtrMobileTheme.surfaceTile,
                contentPadding: JtrResponsive.getResponsivePadding(
                  context,
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    JtrMobileTheme.tileRadius,
                  ),
                  borderSide: BorderSide(
                    color: JtrMobileTheme.borderStrong,
                    width: 0.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    JtrMobileTheme.tileRadius,
                  ),
                  borderSide: BorderSide(
                    color: JtrMobileTheme.borderStrong,
                    width: 0.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    JtrMobileTheme.tileRadius,
                  ),
                  borderSide: BorderSide(
                    color: JtrMobileTheme.accent,
                    width: 1,
                  ),
                ),
              ),
              style: TextStyle(
                fontSize: JtrResponsive.getResponsiveFontSize(context, 12),
                color: JtrMobileTheme.textPrimary,
              ),
            ),
          ),
          SizedBox(width: JtrResponsive.getResponsiveWidth(context, 6)),
          Obx(() {
            final busy = _assistant.isReplying.value;
            return Material(
              color: busy
                  ? JtrMobileTheme.accent.withValues(alpha: 0.5)
                  : JtrMobileTheme.accent,
              borderRadius: BorderRadius.circular(JtrMobileTheme.tileRadius),
              child: InkWell(
                onTap: busy ? null : _send,
                borderRadius: BorderRadius.circular(JtrMobileTheme.tileRadius),
                child: SizedBox(
                  width: JtrResponsive.getResponsiveSize(context, 34),
                  height: JtrResponsive.getResponsiveSize(context, 34),
                  child: busy
                      ? Padding(
                          padding: EdgeInsets.all(
                            JtrResponsive.getResponsiveSize(context, 9),
                          ),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: JtrMobileTheme.accentOnAccent,
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          color: JtrMobileTheme.accentOnAccent,
                          size: JtrResponsive.getResponsiveSize(context, 16),
                        ),
                ),
              ),
            );
          }),
        ],
      ),
    );

    if (widget.expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: list),
          input,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: JtrResponsive.getResponsiveHeight(context, 220),
          ),
          child: list,
        ),
        input,
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final JtrMobileAssistantMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        padding: JtrResponsive.getResponsivePadding(
          context,
          horizontal: 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isUser ? JtrMobileTheme.accentBg : JtrMobileTheme.surfaceTile,
          borderRadius: BorderRadius.circular(JtrMobileTheme.tileRadius),
          border: isUser
              ? Border.all(color: JtrMobileTheme.accent.withValues(alpha: 0.35))
              : null,
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: JtrResponsive.getResponsiveFontSize(context, 12),
            height: 1.45,
            color: JtrMobileTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: JtrResponsive.getResponsivePadding(
          context,
          horizontal: 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: JtrMobileTheme.surfaceTile,
          borderRadius: BorderRadius.circular(JtrMobileTheme.tileRadius),
        ),
        child: Text(
          'Analyse en cours…',
          style: TextStyle(
            fontSize: JtrResponsive.getResponsiveFontSize(context, 12),
            color: JtrMobileTheme.textMuted,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

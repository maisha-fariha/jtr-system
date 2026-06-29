import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/theme_controller.dart';
import '../models/user_suggestion.dart';
import '../utils/app_theme.dart';
import 'user_identifiant_field_controller.dart';

class UserIdentifiantField extends StatelessWidget {
  const UserIdentifiantField({
    super.key,
    required this.controller,
    this.hintText = 'Identifiant',
    this.showFieldIcons = false,
  });

  final UserIdentifiantFieldController controller;
  final String hintText;
  final bool showFieldIcons;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Obx(() {
          if (Get.isRegistered<ThemeController>()) {
            ThemeController.to.isDark.value;
          }

          return CompositedTransformTarget(
            link: controller.identifiantLayerLink,
            child: AuthInputContainer(
              showIcons: showFieldIcons,
              prefixIcon: Icons.person_outline,
              suffixIcon: Icons.keyboard_arrow_down,
              suffixRotation: controller.showSuggestions ? 0.5 : 0,
              onSuffixTap: controller.toggleSuggestions,
              child: TextField(
                controller: controller.textController,
                focusNode: controller.identifiantFocusNode,
                onTap: controller.onIdentifiantTap,
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.darkText,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.55),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          );
        });
      },
    );
  }
}

/// Inserts the suggestions dropdown into the nearest [Overlay] so hit-testing
/// matches the painted position (fixes scroll/select with [CompositedTransformFollower]).
class UserIdentifiantSuggestionsOverlay extends StatefulWidget {
  const UserIdentifiantSuggestionsOverlay({
    super.key,
    required this.controller,
    required this.fieldWidth,
    this.onUserSelected,
  });

  static const fieldHeight = 58.0;

  final UserIdentifiantFieldController controller;
  final double fieldWidth;
  final ValueChanged<UserSuggestion>? onUserSelected;

  @override
  State<UserIdentifiantSuggestionsOverlay> createState() =>
      _UserIdentifiantSuggestionsOverlayState();
}

class _UserIdentifiantSuggestionsOverlayState
    extends State<UserIdentifiantSuggestionsOverlay> {
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant UserIdentifiantSuggestionsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _syncOverlay();
    } else if (oldWidget.fieldWidth != widget.fieldWidth) {
      _overlayEntry?.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _removeOverlay();
    super.dispose();
  }

  void _handleControllerChanged() {
    _syncOverlay();
  }

  void _syncOverlay() {
    final shouldShow = widget.controller.showSuggestions &&
        widget.controller.filteredUsers.isNotEmpty;

    if (shouldShow) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    if (!mounted) return;

    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        builder: (context) => _SuggestionsOverlayLayer(
          controller: widget.controller,
          fieldWidth: widget.fieldWidth,
          onUserSelected: widget.onUserSelected,
        ),
      );
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _SuggestionsOverlayLayer extends StatelessWidget {
  const _SuggestionsOverlayLayer({
    required this.controller,
    required this.fieldWidth,
    this.onUserSelected,
  });

  final UserIdentifiantFieldController controller;
  final double fieldWidth;
  final ValueChanged<UserSuggestion>? onUserSelected;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (Get.isRegistered<ThemeController>()) {
        ThemeController.to.isDark.value;
      }

      return Stack(
        children: [
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => controller.hideSuggestions(unfocus: true),
            ),
          ),
          CompositedTransformFollower(
            link: controller.identifiantLayerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, UserIdentifiantSuggestionsOverlay.fieldHeight),
            child: Material(
              color: Colors.transparent,
              elevation: AppTheme.isDark ? 8 : 4,
              shadowColor: AppTheme.isDark
                  ? Colors.black.withValues(alpha: 0.45)
                  : Colors.black.withValues(alpha: 0.12),
              child: SizedBox(
                width: fieldWidth,
                child: _UserSuggestionsList(
                  users: controller.filteredUsers,
                  onUserSelected: (user) => controller.selectUser(
                    user,
                    onSelected: onUserSelected,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _UserSuggestionsList extends StatelessWidget {
  const _UserSuggestionsList({
    required this.users,
    required this.onUserSelected,
  });

  final List<UserSuggestion> users;
  final ValueChanged<UserSuggestion> onUserSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: AppTheme.suggestionsPanelBackground,
        border: Border(
          left: BorderSide(color: AppTheme.suggestionsPanelBorder),
          right: BorderSide(color: AppTheme.suggestionsPanelBorder),
          bottom: BorderSide(color: AppTheme.suggestionsPanelBorder),
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: users.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          thickness: 1,
          color: AppTheme.cardBorder,
        ),
        itemBuilder: (context, index) {
          final user = users[index];
          return _UserSuggestionTile(
            user: user,
            onTap: () => onUserSelected(user),
          );
        },
      ),
    );
  }
}

class _UserSuggestionTile extends StatelessWidget {
  const _UserSuggestionTile({
    required this.user,
    required this.onTap,
  });

  final UserSuggestion user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  user.id,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.role,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary.withValues(alpha: 0.65),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthInputContainer extends StatelessWidget {
  const AuthInputContainer({
    super.key,
    required this.child,
    this.prefixIcon,
    this.suffixIcon,
    this.suffixRotation = 0,
    this.onSuffixTap,
    this.showIcons = true,
  });

  final Widget child;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final double suffixRotation;
  final VoidCallback? onSuffixTap;
  final bool showIcons;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: UserIdentifiantSuggestionsOverlay.fieldHeight,
      padding: EdgeInsets.symmetric(
        horizontal: showIcons ? 16 : 12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.suggestionsPanelBorder,
        ),
      ),
      child: Row(
        children: [
          if (showIcons && prefixIcon != null) ...[
            Icon(
              prefixIcon,
              color: AppTheme.textSecondary.withValues(alpha: 0.55),
              size: 22,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(child: child),
          if (showIcons && suffixIcon != null) ...[
            GestureDetector(
              onTap: onSuffixTap,
              behavior: HitTestBehavior.opaque,
              child: AnimatedRotation(
                turns: suffixRotation,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  suffixIcon,
                  color: AppTheme.textSecondary.withValues(alpha: 0.55),
                  size: 22,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

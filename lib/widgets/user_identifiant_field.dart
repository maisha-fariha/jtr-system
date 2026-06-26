import 'package:flutter/material.dart';
import '../models/user_suggestion.dart';
import '../utils/app_theme.dart';
import 'auth_input_container.dart';
import 'user_identifiant_field_controller.dart';

// ── Public field widget ────────────────────────────────────────────────────────

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
              focusNode: controller.focusNode,
              onTap: controller.showSuggestionsList,
              style: AppTheme.body1,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: AppTheme.body1.copyWith(color: AppTheme.textLight),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Overlay that renders the suggestions list ──────────────────────────────────

class UserIdentifiantSuggestionsOverlay extends StatefulWidget {
  const UserIdentifiantSuggestionsOverlay({
    super.key,
    required this.controller,
    required this.fieldWidth,
    required this.onUserSelected,
  });

  final UserIdentifiantFieldController controller;
  final double fieldWidth;
  final ValueChanged<UserSuggestion> onUserSelected;

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
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _removeOverlay();
    super.dispose();
  }

  void _onControllerChanged() {
    if (widget.controller.showSuggestions) {
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

// ── Overlay layer ──────────────────────────────────────────────────────────────

class _SuggestionsOverlayLayer extends StatelessWidget {
  const _SuggestionsOverlayLayer({
    required this.controller,
    required this.fieldWidth,
    required this.onUserSelected,
  });

  final UserIdentifiantFieldController controller;
  final double fieldWidth;
  final ValueChanged<UserSuggestion> onUserSelected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Full-screen dismiss listener – only catches events outside the list.
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => controller.hideSuggestions(),
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: controller.identifiantLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 56),
          child: Align(
            alignment: Alignment.topLeft,
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => _UserSuggestionsList(
                users: controller.filteredUsers,
                width: fieldWidth,
                onUserSelected: onUserSelected,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Suggestions list ───────────────────────────────────────────────────────────

class _UserSuggestionsList extends StatelessWidget {
  const _UserSuggestionsList({
    required this.users,
    required this.width,
    required this.onUserSelected,
  });

  final List<UserSuggestion> users;
  final double width;
  final ValueChanged<UserSuggestion> onUserSelected;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        constraints: const BoxConstraints(maxHeight: 220),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.cardShadow,
        ),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: users.length,
          separatorBuilder: (context, index) =>
              const Divider(height: 1, thickness: 1),
          itemBuilder: (context, index) => _UserSuggestionTile(
            user: users[index],
            onTap: () => onUserSelected(users[index]),
          ),
        ),
      ),
    );
  }
}

class _UserSuggestionTile extends StatelessWidget {
  const _UserSuggestionTile({required this.user, required this.onTap});

  final UserSuggestion user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                user.id,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryDark,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name,
                      style: AppTheme.body1
                          .copyWith(fontWeight: FontWeight.w600)),
                  Text(user.role, style: AppTheme.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

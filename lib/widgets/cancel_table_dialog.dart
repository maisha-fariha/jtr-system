import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/theme_controller.dart';
import '../core/network/api_exception.dart';
import '../data/repositories/auth_repository.dart';
import '../models/user_suggestion.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';
import 'user_identifiant_field.dart';
import 'user_identifiant_field_controller.dart';

typedef CancelTableAuthConfirm = Future<void> Function({
  required String userOrId,
  required String passcode,
});

typedef CancelTableNoteConfirm = Future<void> Function({
  required String toWhom,
  required String note,
});

/// Step 1 — user confirmation (identifiant + password).
class CancelTableDialog extends StatefulWidget {
  const CancelTableDialog({
    super.key,
    required this.title,
    required this.onConfirm,
  });

  final String title;
  final CancelTableAuthConfirm onConfirm;

  static Future<void> show({
    required String title,
    required CancelTableAuthConfirm onConfirm,
    BuildContext? context,
  }) {
    final dialogContext = context ?? Get.overlayContext ?? Get.context;
    if (dialogContext == null || !dialogContext.mounted) {
      return Future.value();
    }

    return showDialog<void>(
      context: dialogContext,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => CancelTableDialog(
        title: title,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<CancelTableDialog> createState() => _CancelTableDialogState();
}

class _CancelTableDialogState extends State<CancelTableDialog> {
  final _identifiantController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  late final UserIdentifiantFieldController _identifiantFieldController;

  String? _error;
  bool _isSubmitting = false;
  List<UserSuggestion> _users = const [];

  @override
  void initState() {
    super.initState();
    final cachedUsers = Get.isRegistered<AuthRepository>()
        ? Get.find<AuthRepository>().cachedUserSuggestions
        : const <UserSuggestion>[];
    _users = cachedUsers;
    _identifiantFieldController = UserIdentifiantFieldController(
      textController: _identifiantController,
      hideSuggestionsFocusNode: _passwordFocusNode,
      initialUsers: cachedUsers,
    );
    _identifiantController.addListener(_clearError);
    _passwordController.addListener(_clearError);
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (!Get.isRegistered<AuthRepository>()) return;
    try {
      final users = await Get.find<AuthRepository>().getLoginUsers();
      if (!mounted) return;
      setState(() => _users = users);
      _identifiantFieldController.updateUsers(users);
    } catch (_) {}
  }

  void _clearError() {
    if (_error == null) return;
    setState(() => _error = null);
  }

  UserSuggestion? _resolveUser() {
    final query = _identifiantController.text.trim().toLowerCase();
    if (query.isEmpty) return null;

    for (final user in _users) {
      if (user.id.toLowerCase() == query ||
          user.name.toLowerCase() == query) {
        return user;
      }
    }
    for (final user in _users) {
      if (user.name.toLowerCase().contains(query) ||
          user.id.toLowerCase().contains(query)) {
        return user;
      }
    }
    return null;
  }

  String? _validateLocally() {
    final user = _resolveUser();
    final passcode = _passwordController.text.trim();

    if (_identifiantController.text.trim().isEmpty) {
      return 'Identifiant requis.';
    }
    if (user == null) {
      return 'Sélectionnez un utilisateur valide.';
    }
    if (passcode.isEmpty) {
      return 'Mot de passe requis.';
    }
    if (passcode.length < 4) {
      return 'Mot de passe trop court.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final localError = _validateLocally();
    if (localError != null) {
      setState(() => _error = localError);
      return;
    }

    final user = _resolveUser();
    if (user == null) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await widget.onConfirm(
        userOrId: user.id,
        passcode: _passwordController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isSubmitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de valider cette action.';
        _isSubmitting = false;
      });
    }
  }

  @override
  void dispose() {
    _identifiantController.removeListener(_clearError);
    _passwordController.removeListener(_clearError);
    _identifiantFieldController.dispose();
    _identifiantController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CancelDialogShell(
      title: widget.title,
      isSubmitting: _isSubmitting,
      error: _error,
      onBack: () => Navigator.of(context, rootNavigator: true).pop(),
      onSubmit: _submit,
      submitLabel: 'Se connecter',
      fieldWidthBuilder: (fieldWidth) => UserIdentifiantSuggestionsOverlay(
        controller: _identifiantFieldController,
        fieldWidth: fieldWidth,
      ),
      children: [
        UserIdentifiantField(
          controller: _identifiantFieldController,
          hintText: 'Identifiant, Prénom, Numéro, ...',
          enableAutofill: false,
        ),
        JtrResponsive.getResponsiveSpacing(context, 16),
        AuthInputContainer(
          showIcons: false,
          child: TextField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            obscureText: true,
            enabled: !_isSubmitting,
            onSubmitted: (_) => _submit(),
            autofillHints: const [],
            enableSuggestions: false,
            autocorrect: false,
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 15),
              color: AppTheme.darkText,
            ),
            decoration: InputDecoration(
              hintText: 'Mot de passe',
              hintStyle: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.55),
                fontSize: JtrResponsive.getResponsiveFontSize(context, 15),
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
      ],
    );
  }
}

/// Step 2 — destinataire ("to whom") + note.
class CancelTableNoteDialog extends StatefulWidget {
  const CancelTableNoteDialog({
    super.key,
    required this.title,
    required this.onConfirm,
  });

  final String title;
  final CancelTableNoteConfirm onConfirm;

  static Future<void> show({
    required String title,
    required CancelTableNoteConfirm onConfirm,
    BuildContext? context,
  }) {
    final dialogContext = context ?? Get.overlayContext ?? Get.context;
    if (dialogContext == null || !dialogContext.mounted) {
      return Future.value();
    }

    return showDialog<void>(
      context: dialogContext,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => CancelTableNoteDialog(
        title: title,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<CancelTableNoteDialog> createState() => _CancelTableNoteDialogState();
}

class _CancelTableNoteDialogState extends State<CancelTableNoteDialog> {
  final _toWhomController = TextEditingController();
  final _noteController = TextEditingController();
  final _noteFocusNode = FocusNode();
  late final UserIdentifiantFieldController _toWhomFieldController;

  String? _error;
  bool _isSubmitting = false;
  List<UserSuggestion> _users = const [];

  @override
  void initState() {
    super.initState();
    final cachedUsers = Get.isRegistered<AuthRepository>()
        ? Get.find<AuthRepository>().cachedUserSuggestions
        : const <UserSuggestion>[];
    _users = cachedUsers;
    _toWhomFieldController = UserIdentifiantFieldController(
      textController: _toWhomController,
      hideSuggestionsFocusNode: _noteFocusNode,
      initialUsers: cachedUsers,
    );
    _toWhomController.addListener(_clearError);
    _noteController.addListener(_clearError);
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (!Get.isRegistered<AuthRepository>()) return;
    try {
      final users = await Get.find<AuthRepository>().getLoginUsers();
      if (!mounted) return;
      setState(() => _users = users);
      _toWhomFieldController.updateUsers(users);
    } catch (_) {}
  }

  void _clearError() {
    if (_error == null) return;
    setState(() => _error = null);
  }

  UserSuggestion? _resolveToWhom() {
    final query = _toWhomController.text.trim().toLowerCase();
    if (query.isEmpty) return null;

    for (final user in _users) {
      if (user.id.toLowerCase() == query ||
          user.name.toLowerCase() == query) {
        return user;
      }
    }
    for (final user in _users) {
      if (user.name.toLowerCase().contains(query) ||
          user.id.toLowerCase().contains(query)) {
        return user;
      }
    }
    return null;
  }

  String? _validateLocally() {
    final toWhomText = _toWhomController.text.trim();
    final note = _noteController.text.trim();
    final user = _resolveToWhom();

    if (toWhomText.isEmpty) {
      return 'Destinataire requis.';
    }
    if (user == null && toWhomText.length < 2) {
      return 'Indiquez un destinataire valide.';
    }
    if (note.isEmpty) {
      return 'Note requise.';
    }
    if (note.length < 3) {
      return 'Note trop courte (min. 3 caractères).';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final localError = _validateLocally();
    if (localError != null) {
      setState(() => _error = localError);
      return;
    }

    final user = _resolveToWhom();
    final toWhom = user?.name ?? _toWhomController.text.trim();

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await widget.onConfirm(
        toWhom: toWhom,
        note: _noteController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isSubmitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de valider cette action.';
        _isSubmitting = false;
      });
    }
  }

  @override
  void dispose() {
    _toWhomController.removeListener(_clearError);
    _noteController.removeListener(_clearError);
    _toWhomFieldController.dispose();
    _toWhomController.dispose();
    _noteController.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CancelDialogShell(
      title: widget.title,
      isSubmitting: _isSubmitting,
      error: _error,
      onBack: () => Navigator.of(context, rootNavigator: true).pop(),
      onSubmit: _submit,
      submitLabel: 'Confirmer',
      fieldWidthBuilder: (fieldWidth) => UserIdentifiantSuggestionsOverlay(
        controller: _toWhomFieldController,
        fieldWidth: fieldWidth,
      ),
      children: [
        UserIdentifiantField(
          controller: _toWhomFieldController,
          hintText: 'À qui (destinataire)',
          enableAutofill: false,
        ),
        JtrResponsive.getResponsiveSpacing(context, 16),
        AuthInputContainer(
          showIcons: false,
          child: TextField(
            controller: _noteController,
            focusNode: _noteFocusNode,
            enabled: !_isSubmitting,
            minLines: 2,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            autofillHints: const [],
            enableSuggestions: false,
            autocorrect: false,
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 15),
              color: AppTheme.darkText,
            ),
            decoration: InputDecoration(
              hintText: 'Note',
              hintStyle: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.55),
                fontSize: JtrResponsive.getResponsiveFontSize(context, 15),
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
      ],
    );
  }
}

class _CancelDialogShell extends StatelessWidget {
  const _CancelDialogShell({
    required this.title,
    required this.children,
    required this.onBack,
    required this.onSubmit,
    required this.submitLabel,
    required this.isSubmitting,
    required this.error,
    this.fieldWidthBuilder,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  final String submitLabel;
  final bool isSubmitting;
  final String? error;
  final Widget Function(double fieldWidth)? fieldWidthBuilder;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (Get.isRegistered<ThemeController>()) {
        ThemeController.to.isDark.value;
      }

      final horizontalPadding = JtrResponsive.getResponsiveWidth(context, 20);

      return Dialog(
        backgroundColor: AppTheme.background,
        insetPadding: JtrResponsive.getResponsivePadding(
          context,
          horizontal: 28,
        ),
        clipBehavior: Clip.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            JtrResponsive.getResponsiveRadius(context, 24),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fieldWidth = constraints.maxWidth - (horizontalPadding * 2);

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: JtrResponsive.getResponsivePadding(
                    context,
                    left: horizontalPadding,
                    right: horizontalPadding,
                    top: 16,
                    bottom: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: JtrResponsive.getResponsivePadding(
                            context,
                            all: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.textSecondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              JtrResponsive.getResponsiveRadius(context, 50),
                            ),
                          ),
                          child: IconButton(
                            onPressed: isSubmitting ? null : onBack,
                            icon: Icon(
                              Icons.arrow_back_ios_new,
                              color: AppTheme.darkText,
                              size: JtrResponsive.getResponsiveSize(context, 20),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: JtrResponsive.getResponsiveFontSize(
                            context,
                            18,
                          ),
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText,
                          height: 1.3,
                        ),
                      ),
                      JtrResponsive.getResponsiveSpacing(context, 8),
                      ...children,
                      if (error != null) ...[
                        JtrResponsive.getResponsiveSpacing(context, 10),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFFE74C3C),
                            fontSize: JtrResponsive.getResponsiveFontSize(
                              context,
                              12.5,
                            ),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      JtrResponsive.getResponsiveSpacing(context, 24),
                      SizedBox(
                        width: double.infinity,
                        height: JtrResponsive.getResponsiveHeight(context, 52),
                        child: ElevatedButton(
                          onPressed: isSubmitting ? null : onSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                AppTheme.primary.withValues(alpha: 0.55),
                            elevation: 4,
                            shadowColor:
                                AppTheme.primary.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                JtrResponsive.getResponsiveRadius(context, 16),
                              ),
                            ),
                          ),
                          child: isSubmitting
                              ? SizedBox(
                                  width: JtrResponsive.getResponsiveSize(
                                    context,
                                    22,
                                  ),
                                  height: JtrResponsive.getResponsiveSize(
                                    context,
                                    22,
                                  ),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  submitLabel,
                                  style: TextStyle(
                                    fontSize:
                                        JtrResponsive.getResponsiveFontSize(
                                      context,
                                      17,
                                    ),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (fieldWidthBuilder != null) fieldWidthBuilder!(fieldWidth),
              ],
            );
          },
        ),
      );
    });
  }
}

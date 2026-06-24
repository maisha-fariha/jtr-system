import 'dart:async';

import 'package:flutter/material.dart';

import '../data/demo_users.dart';
import '../models/user_suggestion.dart';

class UserIdentifiantFieldController extends ChangeNotifier {
  UserIdentifiantFieldController({
    required this.textController,
    this.users = demoUsers,
    this.hideSuggestionsFocusNode,
  }) {
    _filteredUsers = List.of(users);
    textController.addListener(_filterUsers);
    identifiantFocusNode.addListener(_onIdentifiantFocusChanged);
    hideSuggestionsFocusNode?.addListener(_onSiblingFocusChanged);
  }

  final identifiantLayerLink = LayerLink();
  final identifiantFocusNode = FocusNode();
  final TextEditingController textController;
  final List<UserSuggestion> users;
  final FocusNode? hideSuggestionsFocusNode;

  bool showSuggestions = false;
  late List<UserSuggestion> _filteredUsers;
  Timer? _suppressToggleTimer;

  List<UserSuggestion> get filteredUsers => _filteredUsers;

  bool get _isSuppressingToggle => _suppressToggleTimer?.isActive ?? false;

  void _onIdentifiantFocusChanged() {
    if (identifiantFocusNode.hasFocus) {
      showSuggestions = true;
      _filterUsers();
    }
  }

  void _onSiblingFocusChanged() {
    if (hideSuggestionsFocusNode?.hasFocus ?? false) {
      hideSuggestions();
    }
  }

  void _filterUsers() {
    final query = textController.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredUsers = List.of(users);
    } else {
      _filteredUsers = users
          .where(
            (user) =>
                user.name.toLowerCase().contains(query) ||
                user.role.toLowerCase().contains(query) ||
                user.id.contains(query),
          )
          .toList();
    }
    notifyListeners();
  }

  void onIdentifiantTap() {
    showSuggestions = true;
    _filterUsers();
  }

  void toggleSuggestions() {
    if (_isSuppressingToggle) return;

    if (showSuggestions) {
      hideSuggestions(unfocus: true);
    } else {
      showSuggestions = true;
      _filterUsers();
      identifiantFocusNode.requestFocus();
    }
  }

  void hideSuggestions({bool unfocus = false}) {
    if (showSuggestions) {
      showSuggestions = false;
      _suppressToggleTimer?.cancel();
      _suppressToggleTimer = Timer(
        const Duration(milliseconds: 250),
        () => _suppressToggleTimer = null,
      );
      if (unfocus) {
        identifiantFocusNode.unfocus();
      }
      notifyListeners();
    }
  }

  void selectUser(UserSuggestion user, {ValueChanged<UserSuggestion>? onSelected}) {
    textController.text = user.name;
    onSelected?.call(user);
    hideSuggestions();
    identifiantFocusNode.unfocus();
  }

  @override
  void dispose() {
    _suppressToggleTimer?.cancel();
    textController.removeListener(_filterUsers);
    identifiantFocusNode.removeListener(_onIdentifiantFocusChanged);
    hideSuggestionsFocusNode?.removeListener(_onSiblingFocusChanged);
    identifiantFocusNode.dispose();
    super.dispose();
  }
}

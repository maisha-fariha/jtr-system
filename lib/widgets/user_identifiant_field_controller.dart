import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_suggestion.dart';
import '../data/demo_users.dart';

/// Encapsulates all state and logic for the identifiant input field
/// and its floating suggestions overlay.
class UserIdentifiantFieldController extends ChangeNotifier {
  UserIdentifiantFieldController() {
    textController.addListener(_filterUsers);
    focusNode.addListener(_onFocusChange);
  }

  final LayerLink identifiantLayerLink = LayerLink();
  final TextEditingController textController = TextEditingController();
  final FocusNode focusNode = FocusNode();

  bool _showSuggestions = false;
  bool get showSuggestions => _showSuggestions;

  List<UserSuggestion> _filteredUsers = List.from(demoUsers);
  List<UserSuggestion> get filteredUsers => _filteredUsers;

  Timer? _suppressToggleTimer;
  bool _suppressToggle = false;

  void _onFocusChange() {
    if (!focusNode.hasFocus && _showSuggestions) {
      hideSuggestions();
    }
  }

  void _filterUsers() {
    final query = textController.text.toLowerCase();
    _filteredUsers = query.isEmpty
        ? List.from(demoUsers)
        : demoUsers
            .where((u) =>
                u.name.toLowerCase().contains(query) ||
                u.id.contains(query))
            .toList();
    if (_showSuggestions) notifyListeners();
  }

  void showSuggestionsList() {
    if (_showSuggestions) return;
    _filteredUsers = List.from(demoUsers);
    _showSuggestions = true;
    notifyListeners();
  }

  void hideSuggestions() {
    if (!_showSuggestions) return;
    _showSuggestions = false;
    notifyListeners();
  }

  void toggleSuggestions() {
    if (_suppressToggle) return;
    if (_showSuggestions) {
      hideSuggestions();
      _suppressToggle = true;
      _suppressToggleTimer?.cancel();
      _suppressToggleTimer = Timer(const Duration(milliseconds: 350), () {
        _suppressToggle = false;
      });
    } else {
      showSuggestionsList();
    }
  }

  void selectUser(UserSuggestion user) {
    textController.text = user.name;
    hideSuggestions();
    focusNode.unfocus();
  }

  @override
  void dispose() {
    _suppressToggleTimer?.cancel();
    textController.removeListener(_filterUsers);
    focusNode.removeListener(_onFocusChange);
    textController.dispose();
    focusNode.dispose();
    super.dispose();
  }
}

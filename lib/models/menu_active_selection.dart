import 'menu_item.dart';
import 'preset_menu.dart';

class MenuActiveSelection {
  const MenuActiveSelection({
    required this.menu,
    required this.choiceNumber,
    required this.selectedItemsByCourse,
    this.messagesByCourse = const {},
  });

  final PresetMenu menu;
  final int choiceNumber;

  /// Selected items grouped by CHOIX (course) number.
  ///
  /// For the requirement "choose N items from the same CHOIX list", we
  /// must support multiple selections per course.
  final Map<int, List<MenuItem>> selectedItemsByCourse;
  final Map<int, String> messagesByCourse;

  int _requiredCountForCourse(int courseNumber) {
    final requested = choiceNumber < 1 ? 1 : choiceNumber;
    final category = menu.categories
        .where((c) => c.number == courseNumber)
        .toList();
    if (category.isEmpty) return requested;
    final maxPossible = category.first.items.length;
    // If there are fewer options than N, the "complete" state is selecting all.
    return requested.clamp(0, maxPossible);
  }

  bool isCourseComplete(int courseNumber) {
    final required = _requiredCountForCourse(courseNumber);
    if (required <= 0) return true;
    final selected = selectedItemsByCourse[courseNumber] ?? const <MenuItem>[];
    return selected.length == required;
  }

  String? messageForCourse(int courseNumber) => messagesByCourse[courseNumber];

  List<MenuItem> get allSelectedItems =>
      selectedItemsByCourse.values.expand((items) => items).toList();

  bool _sameMenuItem(MenuItem a, MenuItem b) {
    if (a.productId != null && b.productId != null) {
      return a.productId == b.productId;
    }
    return a.name == b.name;
  }

  MenuActiveSelection merge(MenuActiveSelection other) {
    final merged = <int, List<MenuItem>>{};
    for (final entry in selectedItemsByCourse.entries) {
      merged[entry.key] = List<MenuItem>.from(entry.value);
    }

    for (final entry in other.selectedItemsByCourse.entries) {
      final current = merged.putIfAbsent(entry.key, () => <MenuItem>[]);
      for (final item in entry.value) {
        final exists = current.any((e) => _sameMenuItem(e, item));
        if (!exists) current.add(item);
      }
    }

    return MenuActiveSelection(
      menu: other.menu,
      choiceNumber: other.choiceNumber,
      selectedItemsByCourse: merged,
      messagesByCourse: {...messagesByCourse, ...other.messagesByCourse},
    );
  }

  MenuActiveSelection withMessage({
    required int courseNumber,
    required String? message,
  }) {
    final messages = Map<int, String>.from(messagesByCourse);
    final trimmed = message?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      messages.remove(courseNumber);
    } else {
      messages[courseNumber] = trimmed;
    }

    return MenuActiveSelection(
      menu: menu,
      choiceNumber: choiceNumber,
      selectedItemsByCourse: selectedItemsByCourse,
      messagesByCourse: messages,
    );
  }
}

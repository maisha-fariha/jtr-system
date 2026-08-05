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

  /// How many menus (quantity) the waiter is adding — not CHOIX option count.
  final int choiceNumber;

  /// Selected items grouped by CHOIX (course) number.
  final Map<int, List<MenuItem>> selectedItemsByCourse;
  final Map<int, String> messagesByCourse;

  bool isCourseComplete(int courseNumber) {
    final matches =
        menu.categories.where((c) => c.number == courseNumber).toList();
    if (matches.isEmpty) return true;
    final category = matches.first;
    final selected =
        selectedItemsByCourse[courseNumber] ?? const <MenuItem>[];
    return category.allowsSelectionCount(selected.length);
  }

  String? messageForCourse(int courseNumber) => messagesByCourse[courseNumber];

  List<MenuItem> get allSelectedItems =>
      selectedItemsByCourse.values.expand((items) => items).toList();

  MenuActiveSelection merge(MenuActiveSelection other) {
    final messages = <int, String>{
      ...messagesByCourse,
      ...other.messagesByCourse,
    };
    messages.removeWhere(
      (course, _) =>
          (other.selectedItemsByCourse[course] ?? const <MenuItem>[]).isEmpty,
    );

    return MenuActiveSelection(
      menu: other.menu,
      choiceNumber: other.choiceNumber,
      selectedItemsByCourse: {
        for (final entry in other.selectedItemsByCourse.entries)
          entry.key: List<MenuItem>.from(entry.value),
      },
      messagesByCourse: messages,
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

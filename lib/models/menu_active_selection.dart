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

  MenuActiveSelection merge(MenuActiveSelection other) {
    // The menu page returns the full current selection for this menu.
    // Replace course lists — do not append. Appending kept deselected items
    // after re-open / unselect / pick-another (left list showed two scoops).
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

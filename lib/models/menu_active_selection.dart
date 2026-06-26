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
  final Map<int, MenuItem> selectedItemsByCourse;
  final Map<int, String> messagesByCourse;

  bool isCourseComplete(int courseNumber) =>
      selectedItemsByCourse.containsKey(courseNumber);

  String? messageForCourse(int courseNumber) => messagesByCourse[courseNumber];

  List<MenuItem> get allSelectedItems =>
      selectedItemsByCourse.values.toList();

  MenuActiveSelection merge(MenuActiveSelection other) {
    return MenuActiveSelection(
      menu: other.menu,
      choiceNumber: other.choiceNumber,
      selectedItemsByCourse: {
        ...selectedItemsByCourse,
        ...other.selectedItemsByCourse,
      },
      messagesByCourse: {
        ...messagesByCourse,
        ...other.messagesByCourse,
      },
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

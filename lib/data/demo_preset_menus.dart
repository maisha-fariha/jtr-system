import '../models/preset_menu.dart';
import 'demo_menu.dart';

final demoPresetMenus = <PresetMenu>[
  PresetMenu(
    number: 1,
    label: 'MENU 1',
    priceValue: 190.00,
    description: 'Formule complète — entrée, plat et dessert au choix.',
    categories: demoMenuCategories,
  ),
  PresetMenu(
    number: 2,
    label: 'MENU 2',
    priceValue: 85.00,
    description: 'Formule midi — entrée et plat au choix.',
    categories: [
      demoMenuCategories[0],
      demoMenuCategories[1],
    ],
  ),
  PresetMenu(
    number: 3,
    label: 'MENU 3',
    priceValue: 120.00,
    description: 'Formule déjeuner — entrée et dessert au choix.',
    categories: [
      demoMenuCategories[0],
      demoMenuCategories[2],
    ],
  ),
];

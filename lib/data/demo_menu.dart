import 'package:flutter/material.dart';

import '../models/menu_category.dart';
import '../models/menu_item.dart';

// Course accent colors extracted from the Figma design system.
const _colorEntrees = Color(0xFFEE8B78);   // primary — CHOIX 1
const _colorPlats = Color(0xFF4A90D9);      // blue    — CHOIX 2
const _colorDesserts = Color(0xFF5BAD6F);   // green   — CHOIX 3

const demoMenuCategories = <MenuCategory>[
  MenuCategory(
    number: 1,
    label: 'ENTRÉES',
    color: _colorEntrees,
    items: [
      MenuItem(name: 'SALADE BURRATA', priceValue: 14.00, courseNumber: 1),
      MenuItem(name: 'SALADE CAESAR', priceValue: 12.00, courseNumber: 1),
      MenuItem(name: 'SALADE DI MARE', priceValue: 16.00, courseNumber: 1),
    ],
  ),
  MenuCategory(
    number: 2,
    label: 'PLATS',
    color: _colorPlats,
    items: [
      MenuItem(name: 'CARRÉ AGNEAU RÔTI', priceValue: 32.00, courseNumber: 2),
      MenuItem(name: 'ESCALOPE DE POULET', priceValue: 24.00, courseNumber: 2),
      MenuItem(name: 'FILET DE BOEUF', priceValue: 38.00, courseNumber: 2),
      MenuItem(name: 'FILET DE DORADE', priceValue: 28.00, courseNumber: 2),
      MenuItem(name: 'FILET ESPADON GRILLÉ', priceValue: 30.00, courseNumber: 2),
    ],
  ),
  MenuCategory(
    number: 3,
    label: 'DESSERTS',
    color: _colorDesserts,
    items: [
      MenuItem(name: 'CHEESECAKE SPECULOS', priceValue: 10.00, courseNumber: 3),
      MenuItem(name: 'FONDANT CHOCOLAT', priceValue: 10.00, courseNumber: 3),
      MenuItem(name: 'GELATO 2 BOULES', priceValue: 8.00, courseNumber: 3),
      MenuItem(name: 'MISTERO DELLA NONNA', priceValue: 12.00, courseNumber: 3),
      MenuItem(name: 'PANNA COTTA', priceValue: 9.00, courseNumber: 3),
    ],
  ),
];

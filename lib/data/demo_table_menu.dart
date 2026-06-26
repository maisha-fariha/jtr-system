class TableMenuItem {
  const TableMenuItem({
    required this.name,
    required this.price,
  });

  final String name;
  final double price;

  String get formattedPrice =>
      '${price.toStringAsFixed(2).replaceAll('.', ',')} €';
}

class TableMenuCategory {
  const TableMenuCategory({
    required this.id,
    required this.label,
    required this.items,
  });

  final String id;
  final String label;
  final List<TableMenuItem> items;
}

const demoTableMenuCategories = [
  TableMenuCategory(
    id: 'plats',
    label: 'PLATS',
    items: [
      TableMenuItem(name: 'Escalope de Poulet', price: 150),
      TableMenuItem(name: 'Saltimbocca Alla Rom', price: 165),
      TableMenuItem(name: 'Filet de bœuf', price: 185),
      TableMenuItem(name: 'Jarret de bœuf', price: 170),
      TableMenuItem(name: 'Carrie agrio roti', price: 145),
      TableMenuItem(name: 'Poulpe Grille', price: 160),
      TableMenuItem(name: 'Côte de Veau', price: 175),
      TableMenuItem(name: 'Magret de Canard', price: 155),
      TableMenuItem(name: 'Dos de Saumon', price: 150),
      TableMenuItem(name: 'Gambas Grillées', price: 180),
      TableMenuItem(name: 'Risotto aux Champignons', price: 140),
      TableMenuItem(name: 'Tajine de Poisson', price: 150),
    ],
  ),
  TableMenuCategory(
    id: 'accompagnements',
    label: 'ACCOMPAGNEMENTS',
    items: [
      TableMenuItem(name: 'Frites Maison', price: 45),
      TableMenuItem(name: 'Riz Basmati', price: 35),
      TableMenuItem(name: 'Légumes Grillés', price: 40),
      TableMenuItem(name: 'Purée Maison', price: 38),
      TableMenuItem(name: 'Salade Verte', price: 30),
      TableMenuItem(name: 'Pommes de Terre', price: 35),
    ],
  ),
  TableMenuCategory(
    id: 'desserts',
    label: 'DESSERTS',
    items: [
      TableMenuItem(name: 'Tiramisu', price: 55),
      TableMenuItem(name: 'Panna Cotta', price: 50),
      TableMenuItem(name: 'Fondant Chocolat', price: 60),
      TableMenuItem(name: 'Gelato 2 Boules', price: 40),
      TableMenuItem(name: 'Cheesecake', price: 55),
    ],
  ),
  TableMenuCategory(
    id: 'boissons',
    label: 'BOISSONS',
    items: [
      TableMenuItem(name: 'Eau Minérale', price: 15),
      TableMenuItem(name: 'Coca-Cola', price: 25),
      TableMenuItem(name: 'Jus d\'Orange', price: 35),
      TableMenuItem(name: 'Café Express', price: 20),
      TableMenuItem(name: 'Thé à la Menthe', price: 25),
      TableMenuItem(name: 'Limonade', price: 20),
    ],
  ),
];

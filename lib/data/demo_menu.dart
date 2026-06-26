import '../models/menu_item.dart';

const demoCategories = [
  MenuCategory(id: 'entrees', name: 'ENTRÉES', iconCode: 0xe5cb),   // soup_kitchen
  MenuCategory(id: 'plats', name: 'PLATS', iconCode: 0xe56c),        // restaurant
  MenuCategory(id: 'grillades', name: 'GRILLADES', iconCode: 0xe02b), // outdoor_grill
  MenuCategory(id: 'pizza', name: 'PIZZAS', iconCode: 0xe1b6),        // local_pizza
  MenuCategory(id: 'desserts', name: 'DESSERTS', iconCode: 0xe235),   // cake
  MenuCategory(id: 'boissons', name: 'BOISSONS', iconCode: 0xe1b8),   // local_bar
  MenuCategory(id: 'softs', name: 'SOFTS', iconCode: 0xe1b9),         // local_drink
];

const demoMenuItems = [
  // Entrées
  MenuItem(id: 'e1', name: 'Salade César', price: 75, categoryId: 'entrees', description: 'Laitue romaine, parmesan, croûtons'),
  MenuItem(id: 'e2', name: 'Soupe du jour', price: 45, categoryId: 'entrees', description: 'Soupe maison du chef'),
  MenuItem(id: 'e3', name: 'Bruschetta', price: 55, categoryId: 'entrees', description: 'Tomates, basilic, huile d\'olive'),
  MenuItem(id: 'e4', name: 'Taboulé', price: 60, categoryId: 'entrees', description: 'Semoule, persil, tomates'),
  MenuItem(id: 'e5', name: 'Assiette charcuterie', price: 95, categoryId: 'entrees', description: 'Sélection de charcuteries'),

  // Plats
  MenuItem(id: 'p1', name: 'Poulet rôti', price: 120, categoryId: 'plats', description: 'Poulet entier rôti, pommes de terre'),
  MenuItem(id: 'p2', name: 'Tajine agneau', price: 145, categoryId: 'plats', description: 'Agneau mijoté, légumes, olives'),
  MenuItem(id: 'p3', name: 'Poisson du jour', price: 135, categoryId: 'plats', description: 'Selon arrivage, légumes de saison'),
  MenuItem(id: 'p4', name: 'Couscous royal', price: 160, categoryId: 'plats', description: 'Semoule, légumes, méchoui'),
  MenuItem(id: 'p5', name: 'Pâtes bolognaise', price: 95, categoryId: 'plats', description: 'Pâtes fraîches, sauce tomate viande'),

  // Grillades
  MenuItem(id: 'g1', name: 'Entrecôte 250g', price: 185, categoryId: 'grillades', description: 'Bœuf grillé, frites maison'),
  MenuItem(id: 'g2', name: 'Côtelettes agneau', price: 165, categoryId: 'grillades', description: 'Côtelettes d\'agneau, légumes grillés'),
  MenuItem(id: 'g3', name: 'Brochettes mixtes', price: 145, categoryId: 'grillades', description: 'Bœuf, poulet, agneau'),
  MenuItem(id: 'g4', name: 'Merguez grillées', price: 110, categoryId: 'grillades', description: '4 pièces, frites'),

  // Pizzas
  MenuItem(id: 'pi1', name: 'Margherita', price: 85, categoryId: 'pizza', description: 'Tomate, mozzarella, basilic'),
  MenuItem(id: 'pi2', name: 'Quatre fromages', price: 100, categoryId: 'pizza', description: 'Mozzarella, chèvre, bleu, parmesan'),
  MenuItem(id: 'pi3', name: 'Orientale', price: 105, categoryId: 'pizza', description: 'Merguez, poivrons, olives'),
  MenuItem(id: 'pi4', name: 'Royale', price: 110, categoryId: 'pizza', description: 'Jambon, champignons, olives'),

  // Desserts
  MenuItem(id: 'd1', name: 'Crème brûlée', price: 55, categoryId: 'desserts', description: 'Crème vanille, caramel craquant'),
  MenuItem(id: 'd2', name: 'Moelleux chocolat', price: 60, categoryId: 'desserts', description: 'Cœur fondant, glace vanille'),
  MenuItem(id: 'd3', name: 'Baklava', price: 45, categoryId: 'desserts', description: 'Pâtisserie orientale au miel'),
  MenuItem(id: 'd4', name: 'Glace 2 boules', price: 40, categoryId: 'desserts', description: 'Choix de parfums'),

  // Boissons
  MenuItem(id: 'b1', name: 'Eau minérale 50cl', price: 15, categoryId: 'boissons', description: ''),
  MenuItem(id: 'b2', name: 'Eau gazeuse 50cl', price: 18, categoryId: 'boissons', description: ''),
  MenuItem(id: 'b3', name: 'Jus d\'orange', price: 35, categoryId: 'boissons', description: 'Pressé à la commande'),
  MenuItem(id: 'b4', name: 'Café express', price: 20, categoryId: 'boissons', description: ''),
  MenuItem(id: 'b5', name: 'Thé à la menthe', price: 25, categoryId: 'boissons', description: 'Menthe fraîche'),

  // Softs
  MenuItem(id: 's1', name: 'Coca-Cola 33cl', price: 25, categoryId: 'softs', description: ''),
  MenuItem(id: 's2', name: 'Sprite 33cl', price: 25, categoryId: 'softs', description: ''),
  MenuItem(id: 's3', name: 'Fanta Orange 33cl', price: 25, categoryId: 'softs', description: ''),
  MenuItem(id: 's4', name: 'Limonade 33cl', price: 20, categoryId: 'softs', description: ''),
];

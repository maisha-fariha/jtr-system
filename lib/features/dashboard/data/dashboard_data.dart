import '../models/order_item.dart';
import '../models/table_order.dart';

/// Central sample data used across dashboard flows.
abstract final class DashboardData {
  static const List<TableOrder> orders = [
    TableOrder(
      tableNumber: 'T5',
      guests: 1,
      post: 'POC1',
      serviceType: 'SUR PLACE',
      covers: 0,
      imprimes: 0,
      total: 630.00,
      isActive: true,
    ),
    TableOrder(
      tableNumber: 'T6',
      guests: 1,
      post: 'POC1',
      serviceType: 'SUR PLACE',
      covers: 0,
      imprimes: 1,
      total: 950.00,
      isActive: false,
    ),
  ];

  static const List<String> availableTables = [
    'T1',
    'T2',
    'T3',
    'T4',
    'T5',
    'T6',
    'T7',
    'T8',
  ];

  static const Map<String, List<OrderItem>> orderItems = {
    'T5': [
      OrderItem(quantity: 1, name: 'SALADE BURRATA', price: 120.00, course: 1),
      OrderItem(quantity: 1, name: 'CARRE AGNEAU ROTI', price: 280.00, course: 2),
      OrderItem(quantity: 1, name: 'CHEESECAKE SPECULOS', price: 90.00, course: 3),
      OrderItem(quantity: 1, name: 'EAU MINERALE', price: 40.00, course: 1),
    ],
    'T6': [
      OrderItem(quantity: 2, name: 'TARTARE DE BOEUF', price: 320.00, course: 1),
      OrderItem(quantity: 1, name: 'FILET DE BAR', price: 380.00, course: 2),
      OrderItem(quantity: 2, name: 'TIRAMISU', price: 180.00, course: 3),
    ],
  };

  static TableOrder? orderFor(String tableNumber) {
    for (final order in orders) {
      if (order.tableNumber == tableNumber) {
        return order;
      }
    }
    return null;
  }

  static List<OrderItem> itemsFor(String tableNumber) {
    return orderItems[tableNumber] ?? const [];
  }

  static List<TableOrder> activeOrders() {
    return orders.where((order) => order.isActive).toList();
  }

  static double get totalRevenue {
    return orders.fold(0, (sum, order) => sum + order.total);
  }

  static int get openTables => orders.length;

  static int get printedTickets =>
      orders.fold(0, (sum, order) => sum + order.imprimes);
}

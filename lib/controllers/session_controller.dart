import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/order_product.dart';
import '../models/session_order.dart';
import '../routes/app_routes.dart';
import '../widgets/cancel_table_dialog.dart';
import '../widgets/table_number_dialog.dart';

enum SessionAction { none, nouvelleCommande, validerCommande, imprimer }

class SessionController extends GetxController {
  final orders = <SessionOrder>[].obs;
  final selectedAction = SessionAction.none.obs;

  @override
  void onInit() {
    super.onInit();
    orders.assignAll(_initialOrders);
  }

  static final _initialOrders = [
    SessionOrder(
      number: 'CMD-001',
      tableNumber: 5,
      products: const [
        OrderProduct(id: 'p1', name: 'Poulet rôti', unitPrice: 120, quantity: 2),
        OrderProduct(id: 'b1', name: 'Eau minérale', unitPrice: 15, quantity: 3),
      ],
    ),
    SessionOrder(
      number: 'CMD-002',
      tableNumber: 12,
      products: const [
        OrderProduct(id: 'e1', name: 'Salade César', unitPrice: 75, quantity: 1),
        OrderProduct(id: 'p4', name: 'Couscous royal', unitPrice: 160, quantity: 2),
        OrderProduct(id: 'd1', name: 'Crème brûlée', unitPrice: 55, quantity: 2),
      ],
    ),
    SessionOrder(
      number: 'CMD-003',
      tableNumber: 3,
      products: const [
        OrderProduct(id: 'g1', name: 'Entrecôte 250g', unitPrice: 185, quantity: 1),
        OrderProduct(id: 's1', name: 'Coca-Cola', unitPrice: 25, quantity: 2),
      ],
    ),
    SessionOrder(
      number: 'CMD-004',
      tableNumber: 8,
      products: const [
        OrderProduct(id: 'pi1', name: 'Margherita', unitPrice: 85, quantity: 2),
        OrderProduct(id: 'pi2', name: 'Quatre fromages', unitPrice: 100, quantity: 1),
        OrderProduct(id: 'b5', name: 'Thé à la menthe', unitPrice: 25, quantity: 2),
      ],
    ),
  ];

  void selectAction(SessionAction action) {
    selectedAction.value =
        selectedAction.value == action ? SessionAction.none : action;
  }

  void toggleOrderExpansion(String orderNumber) {
    final index = orders.indexWhere((o) => o.number == orderNumber);
    if (index == -1) return;
    final order = orders[index];
    orders[index] = order.copyWith(isExpanded: !order.isExpanded);
  }

  void deleteOrder(String orderNumber) {
    orders.removeWhere((o) => o.number == orderNumber);
  }

  void requestDeleteOrder(String orderNumber) {
    CancelTableDialog.show(
      title: 'Annulation Table',
      onConfirm: () => CancelTableDialog.show(
        title: 'Annulation après édition\nnote',
        onConfirm: () => deleteOrder(orderNumber),
      ),
    );
  }

  void requestApplyOffer(String orderNumber) {
    CancelTableDialog.show(
      title: 'Table Offerte',
      onConfirm: () {
        Get.snackbar(
          'Offert',
          'La table a été offerte.',
          backgroundColor: Colors.green.shade50,
          colorText: Colors.green.shade800,
          snackPosition: SnackPosition.BOTTOM,
        );
      },
    );
  }

  void showTableNumberDialog() {
    selectAction(SessionAction.nouvelleCommande);
    TableNumberDialog.show(
      onConfirm: (tableNumber) => Get.toNamed(
        AppRoutes.menu,
        arguments: {'tableNumber': tableNumber},
      ),
    );
  }

  double get sessionTotal =>
      orders.fold(0, (sum, o) => sum + o.total);
}

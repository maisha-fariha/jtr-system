import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/menu_item.dart';
import '../models/order_product.dart';
import '../models/session_order.dart';
import '../routes/app_pages.dart';
import '../utils/app_theme.dart';
import '../widgets/cancel_table_dialog.dart';
import '../widgets/table_number_dialog.dart';
import '../widgets/ticket_loading_dialog.dart';
import '../widgets/ticket_success_dialog.dart';

enum SessionAction {
  nouvelleCommande,
  demanderSuite,
  ticket,
  statistics,
}

class SessionRowSelection {
  const SessionRowSelection({
    required this.orderNumber,
    this.productIndex,
  });

  final String orderNumber;
  final int? productIndex;
}

class SessionTableUiState {
  const SessionTableUiState({
    this.expandedOrderNumber,
    this.selectedRow,
  });

  final String? expandedOrderNumber;
  final SessionRowSelection? selectedRow;

  SessionTableUiState copyWith({
    String? expandedOrderNumber,
    bool clearExpanded = false,
    SessionRowSelection? selectedRow,
    bool clearSelected = false,
  }) {
    return SessionTableUiState(
      expandedOrderNumber:
          clearExpanded ? null : expandedOrderNumber ?? this.expandedOrderNumber,
      selectedRow: clearSelected ? null : selectedRow ?? this.selectedRow,
    );
  }
}

class SessionController extends GetxController {
  final selectedAction = SessionAction.nouvelleCommande.obs;
  final tableUiState = const SessionTableUiState().obs;
  final orders = <SessionOrder>[].obs;

  static const _initialOrders = [
    SessionOrder(
      number: 'T5',
      numberColor: AppTheme.primary,
      group: '1',
      poste: 'POC1',
      profitCenter: 'SUR PLACE',
      couverts: '0',
      impressionCount: 0,
      impressionColor: Color(0xFFE74C3C),
      total: '630,00 €',
      products: [
        OrderProduct(quantity: '1', name: 'SALADE CAESAR', price: '110,00 €'),
        OrderProduct(quantity: '1', name: 'BURGER CLASSIC', price: '150,00 €'),
        OrderProduct(quantity: '2', name: 'FRITES MAISON', price: '80,00 €'),
        OrderProduct(quantity: '2', name: 'COCA COLA', price: '40,00 €'),
        OrderProduct(quantity: '1', name: 'DESSERT DU JOUR', price: '250,00 €'),
      ],
    ),
    SessionOrder(
      number: 'T6',
      numberColor: Color(0xFF7EB8DA),
      group: '1',
      poste: 'POC1',
      profitCenter: 'SUR PLACE',
      couverts: '0',
      impressionCount: 1,
      impressionColor: Color(0xFFF1C40F),
      total: '950,00 €',
      products: [
        OrderProduct(quantity: '2', name: 'PIZZA MARGHERITA', price: '280,00 €'),
        OrderProduct(quantity: '1', name: 'PASTA CARBONARA', price: '220,00 €'),
        OrderProduct(quantity: '3', name: 'EAU MINERALE', price: '30,00 €'),
        OrderProduct(quantity: '2', name: 'TIRAMISU', price: '420,00 €'),
      ],
    ),
  ];

  @override
  void onInit() {
    super.onInit();
    orders.assignAll(_initialOrders);
  }

  void selectAction(SessionAction action) {
    selectedAction.value = action;
  }

  void toggleOrderExpansion(String orderNumber) {
    final current = tableUiState.value.expandedOrderNumber;
    tableUiState.value = tableUiState.value.copyWith(
      expandedOrderNumber: current == orderNumber ? null : orderNumber,
      clearExpanded: current == orderNumber,
    );
  }

  bool isOrderExpanded(String orderNumber) {
    return tableUiState.value.expandedOrderNumber == orderNumber;
  }

  void selectRow({
    required String orderNumber,
    int? productIndex,
    bool expandOnNumberTap = false,
  }) {
    final current = tableUiState.value;
    final isExpanded = current.expandedOrderNumber == orderNumber;

    tableUiState.value = SessionTableUiState(
      expandedOrderNumber: expandOnNumberTap
          ? (isExpanded ? null : orderNumber)
          : current.expandedOrderNumber,
      selectedRow: SessionRowSelection(
        orderNumber: orderNumber,
        productIndex: productIndex,
      ),
    );
  }

  bool isRowSelected({
    required String orderNumber,
    int? productIndex,
  }) {
    final selected = tableUiState.value.selectedRow;
    return selected?.orderNumber == orderNumber &&
        selected?.productIndex == productIndex;
  }

  bool get hasTableSelected {
    final selected = tableUiState.value.selectedRow;
    return selected != null && selected.productIndex == null;
  }

  void showTableNumberDialog() {
    selectAction(SessionAction.nouvelleCommande);
    TableNumberDialog.show(
      onConfirm: (tableNumber) {
        Get.toNamed(
          AppRoutes.menu,
          arguments: {'table': 'T$tableNumber'},
        );
      },
    );
  }

  void requestNextCourse() {
    selectAction(SessionAction.demanderSuite);
    final selected = tableUiState.value.selectedRow;
    if (selected == null || selected.productIndex != null) {
      Get.snackbar(
        'Sélection requise',
        'Veuillez sélectionner une table avant de demander la suite.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      );
      return;
    }
    Get.defaultDialog(
      title: 'Demander la suite',
      middleText:
          'Envoyer la demande de suite pour la table ${selected.orderNumber} ?',
      textConfirm: 'Envoyer',
      textCancel: 'Annuler',
      confirmTextColor: Colors.white,
      buttonColor: AppTheme.primary,
      onConfirm: () {
        Get.back();
        Get.snackbar(
          'Suite demandée',
          'La suite a été envoyée pour la table ${selected.orderNumber}.',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
          backgroundColor: AppTheme.lightButton,
          colorText: AppTheme.darkText,
        );
      },
    );
  }

  void addProductsToOrder(String tableNumber, List<MenuItem> items) {
    if (items.isEmpty) return;

    final newProducts = items
        .map((item) => OrderProduct(
              quantity: '1',
              name: item.name,
              price: item.formattedPrice,
            ))
        .toList();

    final idx = orders.indexWhere((o) => o.number == tableNumber);
    if (idx >= 0) {
      final existing = orders[idx];
      final newTotal =
          _parseTotalString(existing.total) + _sumProducts(newProducts);
      orders[idx] = SessionOrder(
        number: existing.number,
        numberColor: existing.numberColor,
        group: existing.group,
        poste: existing.poste,
        profitCenter: existing.profitCenter,
        couverts: existing.couverts,
        impressionCount: existing.impressionCount,
        impressionColor: existing.impressionColor,
        total: _formatTotal(newTotal),
        products: [...existing.products, ...newProducts],
      );
    } else {
      final total = _sumProducts(newProducts);
      orders.add(SessionOrder(
        number: tableNumber,
        numberColor: AppTheme.primary,
        group: '1',
        poste: 'POC1',
        profitCenter: 'SUR PLACE',
        couverts: '0',
        impressionCount: 0,
        impressionColor: const Color(0xFFE74C3C),
        total: _formatTotal(total),
        products: newProducts,
      ));
    }
  }

  double _sumProducts(List<OrderProduct> products) {
    return products.fold(0, (sum, p) {
      return sum + (_parsePriceString(p.price));
    });
  }

  double _parseTotalString(String total) {
    return double.tryParse(
          total.replaceAll(' €', '').replaceAll(',', '.'),
        ) ??
        0;
  }

  double _parsePriceString(String price) {
    return double.tryParse(
          price.replaceAll(' €', '').replaceAll(',', '.'),
        ) ??
        0;
  }

  String _formatTotal(double value) {
    final formatted = value.toStringAsFixed(2).replaceAll('.', ',');
    return '$formatted €';
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

  void deleteOrder(String orderNumber) {
    orders.removeWhere((order) => order.number == orderNumber);

    final state = tableUiState.value;
    var nextState = state;

    if (state.selectedRow?.orderNumber == orderNumber) {
      nextState = nextState.copyWith(clearSelected: true);
    }
    if (state.expandedOrderNumber == orderNumber) {
      nextState = nextState.copyWith(clearExpanded: true);
    }

    tableUiState.value = nextState;
  }

  void requestApplyOffer(String orderNumber) {
    CancelTableDialog.show(
      title: 'Table Offerte',
      onConfirm: () => applyOffer(orderNumber),
    );
  }

  void applyOffer(String orderNumber) {
    Get.snackbar(
      'Offre',
      'Offre appliquée sur la table $orderNumber.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> printTicket() async {
    if (!hasTableSelected) {
      Get.snackbar(
        'Sélection requise',
        'Veuillez sélectionner une table avant d\'imprimer le ticket.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      );
      return;
    }

    selectAction(SessionAction.ticket);

    Get.dialog(
      const TicketLoadingDialog(),
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
    );

    await Future.delayed(const Duration(seconds: 2));

    if (Get.isDialogOpen ?? false) {
      Get.back();
    }

    await Get.dialog(
      const TicketSuccessDialog(),
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
    );
  }
}

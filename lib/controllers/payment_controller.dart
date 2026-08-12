import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/session_controller.dart';
import '../core/auth/pos_permissions.dart';
import '../core/network/api_exception.dart';
import '../data/mappers/order_mapper.dart';
import '../data/models/payment_draft.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/order_repository.dart';
import '../models/session_order.dart';
import '../utils/app_snackbar.dart';

class PaymentLineInput {
  PaymentLineInput({
    required this.modeId,
    required double amount,
    this.seatNumber,
  })  : amountController = TextEditingController(
          text: amount.toStringAsFixed(2).replaceAll('.', ','),
        ),
        givenController = TextEditingController(
          text: amount.toStringAsFixed(2).replaceAll('.', ','),
        ),
        referenceController = TextEditingController();

  int modeId;
  int? seatNumber;
  final TextEditingController amountController;
  final TextEditingController givenController;
  final TextEditingController referenceController;

  void dispose() {
    amountController.dispose();
    givenController.dispose();
    referenceController.dispose();
  }
}

class PaymentController extends GetxController {
  PaymentController({
    required OrderRepository orderRepository,
    required AuthRepository authRepository,
  })  : _orderRepository = orderRepository,
        _authRepository = authRepository;

  final OrderRepository _orderRepository;
  final AuthRepository _authRepository;

  late final int orderId;
  late final String ticketLabel;
  late final bool preferCash;
  late final int? preferredModeId;
  SessionOrder? localSnapshot;

  final isLoading = true.obs;
  final isSubmitting = false.obs;
  final error = RxnString();
  final remaining = 0.0.obs;
  final totalAmount = 0.0.obs;
  final totalPaid = 0.0.obs;
  final isFullyPaid = false.obs;
  final allowMultiple = true.obs;
  final allowPerSeat = false.obs;
  final perSeatTab = false.obs;
  final modes = <Map<String, dynamic>>[].obs;
  final transactions = <Map<String, dynamic>>[].obs;
  final seats = <Map<String, dynamic>>[].obs;
  final lines = <PaymentLineInput>[].obs;
  final selectedSeat = RxnInt();

  bool get canCancelTransaction =>
      PosPermissions.canDeletePaymentTransaction(
        _authRepository.cachedSession?.user,
      );

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map) {
      orderId = (args['orderId'] as num?)?.toInt() ?? 0;
      ticketLabel = args['ticketLabel']?.toString() ?? '';
      preferCash = args['preferCash'] == true;
      preferredModeId = (args['preferredModeId'] as num?)?.toInt();
      localSnapshot = args['localSnapshot'] as SessionOrder?;
    } else {
      orderId = 0;
      ticketLabel = '';
      preferCash = true;
      preferredModeId = null;
    }
    unawaitedLoad();
  }

  void unawaitedLoad() {
    load();
  }

  @override
  void onClose() {
    for (final line in lines) {
      line.dispose();
    }
    super.onClose();
  }

  Future<void> load() async {
    if (orderId <= 0) {
      error.value = 'Commande introuvable.';
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    error.value = null;
    try {
      final summary = await _orderRepository.getPaymentSummary(orderId);
      remaining.value = OrderMapper.parsePaymentSummaryRemaining(summary);
      totalAmount.value = _money(summary['total_amount']) ?? remaining.value;
      totalPaid.value = _money(summary['total_paid']) ?? 0;
      isFullyPaid.value = summary['is_fully_paid'] == true || remaining.value <= 0.001;
      allowMultiple.value = OrderMapper.allowsMultiplePaymentModes(summary);
      allowPerSeat.value = OrderMapper.allowsPerSeatPayment(summary);
      transactions.assignAll(
        OrderMapper.paymentTransactionsFromSummary(summary),
      );

      final loadedModes = await _orderRepository.getPaymentModes();
      modes.assignAll(loadedModes);

      if (allowPerSeat.value) {
        try {
          seats.assignAll(await _orderRepository.getSeatBreakdown(orderId));
        } catch (_) {
          seats.clear();
        }
      }

      _resetLinesToRemaining();
    } on ApiException catch (e) {
      error.value = e.message;
    } catch (_) {
      error.value = 'Impossible de charger le paiement.';
    } finally {
      isLoading.value = false;
    }
  }

  void _resetLinesToRemaining() {
    for (final line in lines) {
      line.dispose();
    }
    final modeId = _preferredModeId();
    final amount = remaining.value > 0 ? remaining.value : 0.0;
    lines.assignAll([
      PaymentLineInput(
        modeId: modeId,
        amount: amount,
        seatNumber: perSeatTab.value ? selectedSeat.value : null,
      ),
    ]);
  }

  int _preferredModeId() {
    if (modes.isEmpty) return 0;
    final hinted = preferredModeId;
    if (hinted != null && hinted > 0 && modeById(hinted) != null) {
      return hinted;
    }
    final id = OrderMapper.resolvePaymentModeId(modes, isCash: preferCash);
    return id ?? OrderMapper.paymentModeId(modes.first) ?? 0;
  }

  Map<String, dynamic>? modeById(int id) {
    for (final mode in modes) {
      if (OrderMapper.paymentModeId(mode) == id) return mode;
    }
    return modes.isEmpty ? null : modes.first;
  }

  bool isCashLine(PaymentLineInput line) {
    final mode = modeById(line.modeId);
    if (mode == null) return preferCash;
    return OrderMapper.isCashPaymentMode(mode);
  }

  void setLineMode(int index, int modeId) {
    if (index < 0 || index >= lines.length) return;
    lines[index].modeId = modeId;
    lines.refresh();
  }

  void addSplitLine() {
    if (!allowMultiple.value) return;
    final allocated = _sumLineAmounts();
    final leftover = OrderMapper.formatPaymentAmount(
      (remaining.value - allocated).clamp(0, double.infinity),
    );
    lines.add(
      PaymentLineInput(
        modeId: _preferredModeId(),
        amount: leftover,
        seatNumber: perSeatTab.value ? selectedSeat.value : null,
      ),
    );
  }

  void removeLine(int index) {
    if (lines.length <= 1) return;
    if (index < 0 || index >= lines.length) return;
    lines[index].dispose();
    lines.removeAt(index);
  }

  void selectSeat(int seatNumber) {
    selectedSeat.value = seatNumber;
    perSeatTab.value = true;
    for (final line in lines) {
      line.seatNumber = seatNumber;
    }
    lines.refresh();
  }

  void setPerSeatTab(bool value) {
    perSeatTab.value = value;
    for (final line in lines) {
      line.seatNumber = value ? selectedSeat.value : null;
    }
    lines.refresh();
  }

  double _sumLineAmounts() {
    var sum = 0.0;
    for (final line in lines) {
      sum += _parseAmount(line.amountController.text) ?? 0;
    }
    return OrderMapper.formatPaymentAmount(sum);
  }

  static double? _parseAmount(String raw) {
    final cleaned = raw.replaceAll('€', '').replaceAll(' ', '').replaceAll(',', '.').trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  static double? _money(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      return double.tryParse(raw.replaceAll(',', '.').replaceAll('€', '').trim());
    }
    return null;
  }

  Future<void> submit() async {
    if (isSubmitting.value || isFullyPaid.value) return;
    final drafts = <PaymentDraft>[];
    for (final line in lines) {
      final amount = _parseAmount(line.amountController.text);
      if (amount == null || amount <= 0) {
        AppSnackbar.show('Paiement', 'Saisissez un montant valide.');
        return;
      }
      final cash = isCashLine(line);
      double? given;
      if (cash) {
        given = _parseAmount(line.givenController.text) ?? amount;
        if (given < amount) {
          AppSnackbar.show(
            'Paiement',
            'Le montant donné doit être au moins égal au montant à encaisser.',
          );
          return;
        }
      }
      drafts.add(
        PaymentDraft(
          paymentModeId: line.modeId,
          amount: OrderMapper.formatPaymentAmount(amount),
          amountGiven: cash ? OrderMapper.formatPaymentAmount(given ?? amount) : null,
          referenceNumber: cash ? null : line.referenceController.text.trim(),
          seatNumber: perSeatTab.value ? (line.seatNumber ?? selectedSeat.value) : null,
        ),
      );
    }

    if (perSeatTab.value && (selectedSeat.value == null || selectedSeat.value! <= 0)) {
      AppSnackbar.show('Paiement', 'Choisissez un couvert.');
      return;
    }

    isSubmitting.value = true;
    try {
      final result = await _orderRepository.processCheckout(
        orderId: orderId,
        payments: drafts,
        localSnapshot: localSnapshot,
      );
      if (Get.isRegistered<SessionController>()) {
        final session = Get.find<SessionController>();
        if (result.fullyPaid) {
          session.removePaidOrderFromOpenList(result.order);
        } else {
          session.updateOrderRow(result.order, replaceDetail: true);
        }
      }
      if (result.fullyPaid) {
        isFullyPaid.value = true;
        remaining.value = 0;
        Get.back(result: 'fully_paid');
        return;
      }
      AppSnackbar.show(
        'Paiement enregistré',
        'Paiement partiel — le reste peut être encaissé.',
      );
      await load();
    } on ApiException catch (e) {
      AppSnackbar.show('Erreur paiement', e.message);
    } catch (_) {
      AppSnackbar.show('Erreur', 'Impossible d\'enregistrer le paiement.');
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> cancelTransaction(int transactionId) async {
    if (!canCancelTransaction || isSubmitting.value) return;
    isSubmitting.value = true;
    try {
      await _orderRepository.cancelPaymentTransaction(
        orderId: orderId,
        transactionId: transactionId,
        localSnapshot: localSnapshot,
      );
      AppSnackbar.show('Paiement', 'Transaction annulée.');
      await load();
    } on ApiException catch (e) {
      AppSnackbar.show('Erreur', e.message);
    } catch (_) {
      AppSnackbar.show('Erreur', 'Impossible d\'annuler la transaction.');
    } finally {
      isSubmitting.value = false;
    }
  }

  void close() {
    Get.back(result: transactions.isNotEmpty ? 'updated' : null);
  }
}

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
  })  : amountController = TextEditingController(
          text: amount.toStringAsFixed(2).replaceAll('.', ','),
        ),
        givenController = TextEditingController(
          text: amount.toStringAsFixed(2).replaceAll('.', ','),
        ),
        referenceController = TextEditingController();

  int modeId;
  final TextEditingController amountController;
  final TextEditingController givenController;
  final TextEditingController referenceController;

  void dispose() {
    amountController.dispose();
    givenController.dispose();
    referenceController.dispose();
  }
}

/// One seat row for Par couvert (one input card per guest).
class SeatPaymentInput {
  SeatPaymentInput({
    required this.seatNumber,
    required this.modeId,
    required this.remaining,
    this.kitchenRemaining = 0,
    required this.isFullyPaid,
    double? initialAmount,
  })  : amountController = TextEditingController(
          text: initialAmount != null && initialAmount > 0
              ? initialAmount.toStringAsFixed(2).replaceAll('.', ',')
              : '',
        ),
        givenController = TextEditingController(
          text: initialAmount != null && initialAmount > 0
              ? initialAmount.toStringAsFixed(2).replaceAll('.', ',')
              : '',
        ),
        referenceController = TextEditingController();

  final int seatNumber;
  /// Max suggested for UI (order remaining or kitchen seat remaining).
  final double remaining;
  /// Remaining from GET seat-breakdown for this seat (may be 0).
  final double kitchenRemaining;
  final bool isFullyPaid;
  int modeId;
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
  late final bool usesTableFlow;
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
  final seatInputs = <SeatPaymentInput>[].obs;
  final guestCount = 0.obs;

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
      usesTableFlow = args['usesTableFlow'] == true || _zoneUsesTableFlow();
    } else {
      orderId = 0;
      ticketLabel = '';
      preferCash = true;
      preferredModeId = null;
      usesTableFlow = _zoneUsesTableFlow();
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
    _disposeSeatInputs();
    super.onClose();
  }

  bool _zoneUsesTableFlow() {
    if (!Get.isRegistered<SessionController>()) return false;
    return Get.find<SessionController>().selectedZoneUsesTableFlow;
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
      isFullyPaid.value =
          summary['is_fully_paid'] == true || remaining.value <= 0.001;
      allowMultiple.value = OrderMapper.allowsMultiplePaymentModes(summary);
      transactions.assignAll(
        OrderMapper.paymentTransactionsFromSummary(summary),
      );

      var perSeatFlag = OrderMapper.allowsPerSeatPayment(summary);
      if (!perSeatFlag) {
        try {
          final settings = await _orderRepository.getPaymentSettings();
          perSeatFlag = OrderMapper.allowsPerSeatPayment(settings);
        } catch (_) {}
      }

      final loadedModes = await _orderRepository.getPaymentModes();
      modes.assignAll(loadedModes);

      // Use Case D: Par couvert only for table zones + allow_per_seat_payment.
      // No-table zones → Commande only.
      final canShowPerSeat = usesTableFlow &&
          perSeatFlag &&
          !OrderMapper.isFreeZoneTicketOrDraftLabel(
            ticketLabel.isNotEmpty ? ticketLabel : (localSnapshot?.number ?? ''),
          );

      seats.clear();
      guestCount.value = int.tryParse(localSnapshot?.couverts.trim() ?? '') ?? 0;
      if (canShowPerSeat) {
        try {
          final breakdown = await _orderRepository.getSeatBreakdown(orderId);
          seats.assignAll(breakdown.seats);
          if (breakdown.numberOfGuests > guestCount.value) {
            guestCount.value = breakdown.numberOfGuests;
          }
        } catch (_) {
          seats.clear();
        }
      }

      // Show Par couvert when we know guests (even if seat_summary is sparse).
      allowPerSeat.value = canShowPerSeat && guestCount.value >= 1;
      if (!allowPerSeat.value) {
        perSeatTab.value = false;
        _disposeSeatInputs();
        seatInputs.clear();
      } else if (perSeatTab.value) {
        _rebuildSeatInputs();
      }

      if (!perSeatTab.value) {
        _resetLinesToRemaining();
      }
    } on ApiException catch (e) {
      error.value = e.message;
    } catch (_) {
      error.value = 'Impossible de charger le paiement.';
    } finally {
      isLoading.value = false;
    }
  }

  void _disposeSeatInputs() {
    for (final input in seatInputs) {
      input.dispose();
    }
  }

  void _rebuildSeatInputs() {
    _disposeSeatInputs();
    final defaultMode = _preferredModeId();
    final byNumber = <int, Map<String, dynamic>>{};
    for (final seat in seats) {
      final number = (seat['seat_number'] as num?)?.toInt() ?? 0;
      if (number > 0) byNumber[number] = seat;
    }

    var count = guestCount.value;
    if (count < 1 && byNumber.isNotEmpty) {
      count = byNumber.keys.reduce((a, b) => a > b ? a : b);
    }
    if (count < 1) count = byNumber.length;
    if (count < 1) return;

    // Kitchen seat balances (Use Case D). Often only seat 1 has items.
    final kitchenRemain = <int, double>{};
    var kitchenTotal = 0.0;
    for (final entry in byNumber.entries) {
      final remain = OrderMapper.formatPaymentAmount(
        OrderMapper.parsePaymentSummaryRemaining(entry.value),
      );
      kitchenRemain[entry.key] = remain;
      kitchenTotal += remain;
    }

    // Free cover split: every guest can pay. Suggest equal share of order remaining
    // when items are not assigned per seat (kitchen total ≈ all on one seat).
    final orderRemain = OrderMapper.formatPaymentAmount(remaining.value);
    final equalShare = OrderMapper.formatPaymentAmount(orderRemain / count);
    final useEqualShare =
        orderRemain > 0.001 && (kitchenTotal <= 0.001 || kitchenTotal + 0.05 < orderRemain || byNumber.length < count);

    final built = <SeatPaymentInput>[];
    for (var i = 1; i <= count; i++) {
      final seat = byNumber[i];
      final kitchen = kitchenRemain[i] ?? 0.0;
      final paid = seat != null &&
          (seat['is_fully_paid'] == true || kitchen <= 0.001) &&
          !useEqualShare &&
          orderRemain <= 0.001;

      // Cap for this guest: kitchen balance if strict & > 0, else order remaining
      // (client still enforces sum ≤ order remaining on submit).
      final guestCap = (!useEqualShare && kitchen > 0.001)
          ? kitchen
          : orderRemain;
      final initial = paid
          ? null
          : (useEqualShare
              ? equalShare
              : (kitchen > 0.001 ? kitchen : null));

      built.add(
        SeatPaymentInput(
          seatNumber: i,
          modeId: defaultMode,
          remaining: guestCap,
          kitchenRemaining: kitchen,
          isFullyPaid: paid,
          initialAmount: initial,
        ),
      );
    }
    seatInputs.assignAll(built);
  }

  void _resetLinesToRemaining() {
    for (final line in lines) {
      line.dispose();
    }
    final modeId = _preferredModeId();
    final amount = remaining.value > 0 ? remaining.value : 0.0;
    lines.assignAll([
      PaymentLineInput(modeId: modeId, amount: amount),
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

  bool isCashSeat(SeatPaymentInput input) {
    final mode = modeById(input.modeId);
    if (mode == null) return preferCash;
    return OrderMapper.isCashPaymentMode(mode);
  }

  void setLineMode(int index, int modeId) {
    if (index < 0 || index >= lines.length) return;
    lines[index].modeId = modeId;
    lines.refresh();
  }

  void setSeatMode(int seatNumber, int modeId) {
    final index = seatInputs.indexWhere((s) => s.seatNumber == seatNumber);
    if (index < 0) return;
    seatInputs[index].modeId = modeId;
    seatInputs.refresh();
  }

  void addSplitLine() {
    if (!allowMultiple.value || perSeatTab.value) return;
    final allocated = _sumLineAmounts();
    final leftover = OrderMapper.formatPaymentAmount(
      (remaining.value - allocated).clamp(0, double.infinity),
    );
    lines.add(
      PaymentLineInput(modeId: _preferredModeId(), amount: leftover),
    );
  }

  void removeLine(int index) {
    if (lines.length <= 1) return;
    if (index < 0 || index >= lines.length) return;
    lines[index].dispose();
    lines.removeAt(index);
  }

  void setPerSeatTab(bool value) {
    if (value && !allowPerSeat.value) return;
    perSeatTab.value = value;
    if (value) {
      _rebuildSeatInputs();
    } else {
      _disposeSeatInputs();
      seatInputs.clear();
      _resetLinesToRemaining();
    }
  }

  double _sumLineAmounts() {
    var sum = 0.0;
    for (final line in lines) {
      sum += _parseAmount(line.amountController.text) ?? 0;
    }
    return OrderMapper.formatPaymentAmount(sum);
  }

  static double? _parseAmount(String raw) {
    final cleaned =
        raw.replaceAll('€', '').replaceAll(' ', '').replaceAll(',', '.').trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  static double? _money(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      return double.tryParse(
        raw.replaceAll(',', '.').replaceAll('€', '').trim(),
      );
    }
    return null;
  }

  Future<void> submit() async {
    if (isSubmitting.value || isFullyPaid.value) return;
    final drafts =
        perSeatTab.value ? _draftsFromSeats() : _draftsFromCommande();
    if (drafts == null) return;

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

  List<PaymentDraft>? _draftsFromCommande() {
    final drafts = <PaymentDraft>[];
    for (final line in lines) {
      final amount = _parseAmount(line.amountController.text);
      if (amount == null || amount <= 0) {
        AppSnackbar.show('Paiement', 'Saisissez un montant valide.');
        return null;
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
          return null;
        }
      }
      drafts.add(
        PaymentDraft(
          paymentModeId: line.modeId,
          amount: OrderMapper.formatPaymentAmount(amount),
          amountGiven:
              cash ? OrderMapper.formatPaymentAmount(given ?? amount) : null,
          referenceNumber: cash ? null : line.referenceController.text.trim(),
        ),
      );
    }
    return drafts;
  }

  /// Par couvert — every guest can pay; empty = skip.
  /// Sum must be ≤ order remaining. Uses process-per-seat only when each
  /// amount fits that seat's kitchen balance; otherwise process-multiple.
  List<PaymentDraft>? _draftsFromSeats() {
    final drafts = <PaymentDraft>[];
    for (final input in seatInputs) {
      if (input.isFullyPaid) continue;
      final raw = input.amountController.text.trim();
      if (raw.isEmpty) continue;

      final amount = _parseAmount(raw);
      if (amount == null || amount < 0) {
        AppSnackbar.show(
          'Paiement',
          'Montant invalide pour le couvert ${input.seatNumber}.',
        );
        return null;
      }
      if (amount == 0) continue;

      if (input.modeId <= 0) {
        AppSnackbar.show(
          'Paiement',
          'Choisissez un mode pour le couvert ${input.seatNumber}.',
        );
        return null;
      }

      final cash = isCashSeat(input);
      double? given;
      if (cash) {
        given = _parseAmount(input.givenController.text) ?? amount;
        if (given < amount) {
          AppSnackbar.show(
            'Paiement',
            'Couvert ${input.seatNumber}: le montant donné doit être '
                'au moins égal au montant à encaisser.',
          );
          return null;
        }
      }

      drafts.add(
        PaymentDraft(
          paymentModeId: input.modeId,
          amount: OrderMapper.formatPaymentAmount(amount),
          amountGiven:
              cash ? OrderMapper.formatPaymentAmount(given ?? amount) : null,
          referenceNumber:
              cash ? null : input.referenceController.text.trim(),
          seatNumber: input.seatNumber,
        ),
      );
    }

    if (drafts.isEmpty) {
      AppSnackbar.show(
        'Paiement',
        'Saisissez un montant pour au moins un couvert.',
      );
      return null;
    }

    final total = OrderMapper.formatPaymentAmount(
      drafts.fold<double>(0, (sum, d) => sum + d.amount),
    );
    if (total > remaining.value + 0.001) {
      AppSnackbar.show(
        'Paiement',
        'Le total des couverts dépasse le reste à payer '
            '(${remaining.value.toStringAsFixed(2).replaceAll('.', ',')} €).',
      );
      return null;
    }

    return drafts;
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

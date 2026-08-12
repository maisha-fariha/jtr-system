class PaymentDraft {
  const PaymentDraft({
    required this.paymentModeId,
    required this.amount,
    this.amountGiven,
    this.referenceNumber,
    this.seatNumber,
  });

  final int paymentModeId;
  final double amount;
  final double? amountGiven;
  final String? referenceNumber;
  final int? seatNumber;

  Map<String, dynamic> toApiMap({bool includeSeat = false}) {
    return {
      'payment_mode_id': paymentModeId,
      'amount': amount,
      if (amountGiven != null) 'amount_given': amountGiven,
      if (referenceNumber != null && referenceNumber!.trim().isNotEmpty)
        'reference_number': referenceNumber!.trim(),
      if (includeSeat && seatNumber != null && seatNumber! > 0)
        'seat_number': seatNumber,
    };
  }
}

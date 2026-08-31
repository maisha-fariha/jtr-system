import 'package:flutter/services.dart';

/// Clears the field on backspace when the value is zero (e.g. "0,00").
class ZeroAmountBackspaceClearFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length < oldValue.text.length) {
      final cleaned = oldValue.text
          .replaceAll('€', '')
          .replaceAll(' ', '')
          .replaceAll(',', '.')
          .trim();
      if (cleaned.isNotEmpty) {
        final amount = double.tryParse(cleaned);
        if (amount != null && amount.abs() < 0.001) {
          return const TextEditingValue(
            text: '',
            selection: TextSelection.collapsed(offset: 0),
          );
        }
      }
    }
    return newValue;
  }
}

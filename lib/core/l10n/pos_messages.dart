import 'package:get/get.dart';

/// User-facing POS strings (French default, English when locale is en).
class PosMessages {
  PosMessages._();

  static bool get _isEnglish {
    final code = Get.locale?.languageCode ?? 'fr';
    return code.startsWith('en');
  }

  static String productOutOfStockTitle() =>
      _isEnglish ? 'Out of stock' : 'Rupture de stock';

  static String productOutOfStockBody() => _isEnglish
      ? 'This product is out of stock.'
      : 'Ce produit est en rupture de stock.';

  static String actionNotPermittedTitle() =>
      _isEnglish ? 'Action not permitted' : 'Action non autorisée';

  static String actionNotPermittedBody() => _isEnglish
      ? 'You don\'t have permission to perform this action.'
      : 'Vous n\'avez pas la permission d\'effectuer cette action.';
}

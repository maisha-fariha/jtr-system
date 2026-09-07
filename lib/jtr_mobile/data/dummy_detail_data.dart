import '../models/detail_models.dart';
import '../theme/jtr_mobile_theme.dart';

class JtrMobileDummyDetailData {
  JtrMobileDummyDetailData._();

  static List<JtrProductFamily> families() {
    return const [
      JtrProductFamily(
        name: 'Tajines',
        totalQuantity: 451,
        totalAmount: 62000,
        articles: [
          JtrFamilyArticle(name: 'Tajine agneau', quantity: 210, amount: 32000),
          JtrFamilyArticle(name: 'Tajine poulet', quantity: 145, amount: 18000),
          JtrFamilyArticle(name: 'Tajine kefta', quantity: 96, amount: 12000),
        ],
      ),
      JtrProductFamily(
        name: 'Grillades',
        totalQuantity: 355,
        totalAmount: 58000,
        articles: [
          JtrFamilyArticle(
            name: 'Brochettes viande',
            quantity: 180,
            amount: 30000,
          ),
          JtrFamilyArticle(
            name: 'Brochettes poulet',
            quantity: 175,
            amount: 28000,
          ),
        ],
      ),
      JtrProductFamily(
        name: 'Boissons froides',
        totalQuantity: 1550,
        totalAmount: 45000,
        articles: [
          JtrFamilyArticle(name: "Jus d'orange", quantity: 400, amount: 20000),
          JtrFamilyArticle(name: 'Soda', quantity: 500, amount: 15000),
          JtrFamilyArticle(name: 'Eau minérale', quantity: 650, amount: 10000),
        ],
      ),
      JtrProductFamily(
        name: 'Boissons chaudes',
        totalQuantity: 1670,
        totalAmount: 60100,
        articles: [
          JtrFamilyArticle(
            name: 'Thé à la menthe',
            quantity: 1000,
            amount: 40000,
          ),
          JtrFamilyArticle(name: 'Café', quantity: 670, amount: 20100),
        ],
      ),
      JtrProductFamily(
        name: 'Desserts',
        totalQuantity: 540,
        totalAmount: 54000,
        articles: [
          JtrFamilyArticle(
            name: 'Pâtisserie orientale',
            quantity: 310,
            amount: 31000,
          ),
          JtrFamilyArticle(name: 'Fruits frais', quantity: 230, amount: 23000),
        ],
      ),
    ];
  }

  static List<JtrGapCategoryDetail> gapCategories() {
    return [
      JtrGapCategoryDetail(
        label: 'Annulations',
        color: JtrMobileTheme.danger,
        totalAmount: 12400,
        transactions: const [
          JtrGapTransaction(
            meta: '04/08 · 13:20 · Table 22',
            label: 'Tajine agneau',
            quantity: 1,
            tag: 'Erreur de saisie',
            amount: 120,
          ),
          JtrGapTransaction(
            meta: '06/08 · 20:05 · Table 87',
            label: 'Brochettes poulet',
            quantity: 2,
            tag: 'Client insatisfait',
            amount: 180,
          ),
          JtrGapTransaction(
            meta: '09/08 · 12:40 · Table 14',
            label: "Jus d'orange",
            quantity: 3,
            tag: 'Rupture de stock',
            amount: 60,
          ),
          JtrGapTransaction(
            meta: '12/08 · 19:15 · Table 156',
            label: 'Thé à la menthe',
            quantity: 2,
            tag: 'Autre motif',
            amount: 40,
          ),
        ],
      ),
      JtrGapCategoryDetail(
        label: 'Remises',
        color: JtrMobileTheme.warning,
        totalAmount: 8900,
        transactions: const [
          JtrGapTransaction(
            meta: '02/08 · 21:40 · Table 136',
            label: 'Menu complet',
            tag: 'Remise fidélité',
            discountPercent: 10,
            amount: 210,
          ),
          JtrGapTransaction(
            meta: '05/08 · 14:10 · Table 40',
            label: 'Addition groupe',
            tag: 'Remise groupe',
            discountPercent: 15,
            amount: 350,
          ),
          JtrGapTransaction(
            meta: '11/08 · 21:00 · Table 8',
            label: 'Repas direction',
            tag: 'Remise direction',
            discountPercent: 20,
            amount: 180,
          ),
        ],
      ),
      JtrGapCategoryDetail(
        label: 'Offerts',
        color: JtrMobileTheme.pro,
        totalAmount: 3100,
        transactions: const [
          JtrGapTransaction(
            meta: '02/08 · 21:13 · Table 136',
            label: 'Bento',
            quantity: 1,
            amount: 115,
          ),
          JtrGapTransaction(
            meta: '02/08 · 21:13 · Table 156',
            label: 'Croquette saumon',
            quantity: 1,
            amount: 50,
          ),
          JtrGapTransaction(
            meta: '02/08 · 21:13 · Table 156',
            label: 'Croquette fromage',
            quantity: 1,
            amount: 35,
          ),
          JtrGapTransaction(
            meta: '02/08 · 21:13 · Table 50',
            label: 'Nem viet veggie',
            quantity: 1,
            amount: 30,
          ),
          JtrGapTransaction(
            meta: '02/08 · 22:44 · Table 136',
            label: 'Wok cajou poulet',
            quantity: 1,
            amount: 75,
          ),
          JtrGapTransaction(
            meta: '04/08 · 07:52 · Table 136',
            label: 'Wok basilic poulet',
            quantity: 1,
            amount: 80,
          ),
        ],
      ),
      JtrGapCategoryDetail(
        label: 'Pertes',
        color: JtrMobileTheme.info,
        totalAmount: 1250,
        transactions: const [
          JtrGapTransaction(
            meta: '07/08 · 09:00 · Cuisine',
            label: 'Casse verrerie',
            tag: 'Casse',
            amount: 650,
          ),
          JtrGapTransaction(
            meta: '15/08 · 18:30 · Cuisine',
            label: 'Péremption légumes',
            tag: 'Péremption',
            amount: 600,
          ),
        ],
      ),
    ];
  }
}

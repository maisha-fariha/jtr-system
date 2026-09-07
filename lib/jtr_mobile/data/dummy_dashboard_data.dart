import '../models/dashboard_models.dart';
import '../theme/jtr_mobile_theme.dart';

class JtrMobileDummyData {
  JtrMobileDummyData._();

  static JtrDashboardData dashboard() {
    return JtrDashboardData(
      storeName: 'Restaurant Demo',
      dateLabel: "Aujourd'hui · en direct",
      periodLabel: 'Août 2026',
      kpis: const JtrDashboardKpis(
        revenue: 439100,
        collected: 413450,
        trendLabel: '+6% vs juillet',
        trendPositive: true,
      ),
      payments: const [
        JtrPaymentBreakdownItem(
          label: 'Espèces',
          amount: 210000,
          percent: 51,
        ),
        JtrPaymentBreakdownItem(
          label: 'TPE',
          amount: 180450,
          percent: 44,
        ),
        JtrPaymentBreakdownItem(
          label: 'Chèque',
          amount: 23000,
          percent: 5,
        ),
      ],
      gapSegments: [
        JtrGapSegment(
          label: 'Annulations',
          amount: 12400,
          color: JtrMobileTheme.danger,
        ),
        JtrGapSegment(
          label: 'Remises',
          amount: 8900,
          color: JtrMobileTheme.warning,
        ),
        JtrGapSegment(
          label: 'Offerts',
          amount: 3100,
          color: JtrMobileTheme.pro,
        ),
        JtrGapSegment(
          label: 'Pertes',
          amount: 1250,
          color: JtrMobileTheme.accent,
        ),
      ],
      gapTotal: 25650,
      categories: [
        JtrCategoryRevenue(
          name: 'Nourriture',
          amount: 236000,
          percent: 54,
          color: JtrMobileTheme.accent,
        ),
        JtrCategoryRevenue(
          name: 'Boisson',
          amount: 105100,
          percent: 24,
          color: JtrMobileTheme.pro,
        ),
        JtrCategoryRevenue(
          name: 'Divers',
          amount: 98000,
          percent: 22,
          color: JtrMobileTheme.warning,
        ),
      ],
      zones: [
        JtrZoneRevenue(
          name: 'Sur place',
          amount: 250000,
          percent: 57,
          color: JtrMobileTheme.accent,
        ),
        JtrZoneRevenue(
          name: 'Emporter',
          amount: 95000,
          percent: 22,
          color: JtrMobileTheme.success,
        ),
        JtrZoneRevenue(
          name: 'Livraison',
          amount: 60000,
          percent: 14,
          color: JtrMobileTheme.pro,
        ),
        JtrZoneRevenue(
          name: 'Glovo',
          amount: 34100,
          percent: 7,
          color: JtrMobileTheme.warning,
        ),
      ],
      activity: const JtrActivityStats(
        tickets: 3820,
        avgTicket: 133,
        covers: 9650,
        avgCover: 45.5,
      ),
      movements: [
        JtrMovementRow(
          label: 'Notes soldées',
          value: '3 790',
          subValue: null,
          color: JtrMobileTheme.success,
        ),
        JtrMovementRow(
          label: 'Notes ouvertes',
          value: '14',
          subValue: '2 380 DH',
          color: JtrMobileTheme.warning,
        ),
        JtrMovementRow(
          label: 'Transferts table',
          value: '47',
          subValue: null,
          color: JtrMobileTheme.accent,
        ),
        JtrMovementRow(
          label: 'Transferts article',
          value: '63',
          subValue: null,
          color: JtrMobileTheme.pro,
        ),
        JtrMovementRow(
          label: 'Annulations paiement',
          value: '9',
          subValue: null,
          color: JtrMobileTheme.danger,
          highlightDanger: true,
        ),
      ],
      hourlyBars: const [
        JtrHourlyBar(hourLabel: '10h', amount: 200, isPeak: false),
        JtrHourlyBar(hourLabel: '', amount: 1400, isPeak: false),
        JtrHourlyBar(hourLabel: '12h', amount: 9800, isPeak: false),
        JtrHourlyBar(hourLabel: '', amount: 10600, isPeak: false),
        JtrHourlyBar(hourLabel: '14h', amount: 5800, isPeak: false),
        JtrHourlyBar(hourLabel: '', amount: 2000, isPeak: false),
        JtrHourlyBar(hourLabel: '16h', amount: 1000, isPeak: false),
        JtrHourlyBar(hourLabel: '', amount: 1200, isPeak: false),
        JtrHourlyBar(hourLabel: '18h', amount: 3600, isPeak: false),
        JtrHourlyBar(hourLabel: '', amount: 11000, isPeak: false),
        JtrHourlyBar(hourLabel: '20h', amount: 12400, isPeak: true),
        JtrHourlyBar(hourLabel: '', amount: 11200, isPeak: false),
        JtrHourlyBar(hourLabel: '22h', amount: 6800, isPeak: false),
        JtrHourlyBar(hourLabel: '', amount: 2400, isPeak: false),
      ],
      peakCaption: 'Pic à 20h · 12 400 DH',
      periodFrom: DateTime(2026, 8, 1),
      periodTo: DateTime(2026, 8, 29),
    );
  }
}

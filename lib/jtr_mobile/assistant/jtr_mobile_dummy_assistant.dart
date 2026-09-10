import '../models/dashboard_models.dart';
import '../utils/jtr_mobile_formatters.dart';

/// Local dummy “AI” — keyword replies from current [JtrDashboardData].
///
/// No network. Replace with a real repository calling the backend API later.
class JtrMobileDummyAssistant {
  const JtrMobileDummyAssistant();

  static const welcomeText =
      'Bonjour 👋 Je peux vous résumer vos ventes, expliquer un '
      'écart ou comparer deux périodes. Que voulez-vous savoir ?\n\n'
      '(Réponses simulées à partir des données du tableau de bord — '
      'API backend à venir.)';

  /// Simulated latency so the UI feels like a remote call.
  Future<String> reply({
    required String userMessage,
    required JtrDashboardData? data,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 550));
    return _analyze(userMessage.trim(), data);
  }

  String _analyze(String raw, JtrDashboardData? data) {
    if (data == null) {
      return 'Les données du tableau de bord ne sont pas encore chargées. '
          'Réessayez dans un instant.';
    }

    final q = raw.toLowerCase();
    if (q.isEmpty) {
      return 'Posez-moi une question sur le CA, l’écart, les paiements, '
          'les catégories, les zones ou l’activité.';
    }

    if (_matches(q, const [
      'écart',
      'ecart',
      'annulation',
      'remise',
      'offert',
      'perte',
      'non encaiss',
    ])) {
      return _gapSummary(data);
    }

    if (_matches(q, const [
      'paiement',
      'espèce',
      'espece',
      'tpe',
      'chèque',
      'cheque',
      'virement',
      'glovo',
      'mode de paiement',
    ])) {
      return _paymentsSummary(data);
    }

    if (_matches(q, const [
      'catégorie',
      'categorie',
      'famille',
      'boisson',
      'nourriture',
      'produit',
    ])) {
      return _categoriesSummary(data);
    }

    if (_matches(q, const ['zone', 'salle', 'terrasse', 'sur place', 'emporter'])) {
      return _zonesSummary(data);
    }

    if (_matches(q, const [
      'heure',
      'horaire',
      'peak',
      'pic',
      'affluence',
    ])) {
      return _hourlySummary(data);
    }

    if (_matches(q, const [
      'ticket',
      'couvert',
      'activité',
      'activite',
      'moyenne',
    ])) {
      return _activitySummary(data);
    }

    if (_matches(q, const [
      'mouvement',
      'transfert',
      'note ouverte',
      'soldée',
      'soldee',
    ])) {
      return _movementsSummary(data);
    }

    if (_matches(q, const [
      'compar',
      'période',
      'periode',
      'vs',
      'tendance',
      'évolution',
      'evolution',
    ])) {
      return _periodSummary(data);
    }

    if (_matches(q, const [
      'vente',
      'ca',
      'chiffre',
      'résumé',
      'resume',
      'résumer',
      'resumer',
      'encaiss',
      'revenu',
      'summary',
      'bonjour',
      'salut',
      'aide',
      'help',
    ])) {
      return _salesSummary(data);
    }

    // Default: short overview + tip.
    return '${_salesSummary(data)}\n\n'
        'Astuce : demandez « résumé », « écart », « paiements », '
        '« catégories », « zones » ou « heures ».';
  }

  bool _matches(String q, List<String> keys) =>
      keys.any((k) => q.contains(k));

  String _salesSummary(JtrDashboardData d) {
    final k = d.kpis;
    final gap = d.gapTotal;
    final topPay = d.payments.isEmpty
        ? null
        : (List<JtrPaymentBreakdownItem>.from(d.payments)
              ..sort((a, b) => b.amount.compareTo(a.amount)))
            .first;
    final topCat = d.categories.isEmpty
        ? null
        : (List<JtrCategoryRevenue>.from(d.categories)
              ..sort((a, b) => b.amount.compareTo(a.amount)))
            .first;

    final buf = StringBuffer()
      ..writeln('📊 Résumé des ventes (${d.periodLabel})')
      ..writeln('• Chiffre d’affaires : ${JtrMobileFormatters.currency(k.revenue)}')
      ..writeln(
        '• Encaissé : ${JtrMobileFormatters.currency(k.collected)} '
        '(${JtrMobileFormatters.percent(k.collectedPercentOfRevenue)} du CA)',
      )
      ..writeln('• Tendance : ${k.trendLabel}')
      ..writeln('• Écart non encaissé : ${JtrMobileFormatters.currency(gap)}');

    if (topPay != null) {
      buf.writeln(
        '• Paiement dominant : ${topPay.label} '
        '(${JtrMobileFormatters.currency(topPay.amount)}, '
        '${JtrMobileFormatters.percent(topPay.percent)})',
      );
    }
    if (topCat != null) {
      buf.writeln(
        '• Catégorie dominante : ${topCat.name} '
        '(${JtrMobileFormatters.currency(topCat.amount)})',
      );
    }
    buf.write(
      '• Activité : ${JtrMobileFormatters.integer(d.activity.tickets)} tickets, '
      '${JtrMobileFormatters.integer(d.activity.covers)} couverts',
    );
    return buf.toString();
  }

  String _gapSummary(JtrDashboardData d) {
    final segs = List<JtrGapSegment>.from(d.gapSegments)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final buf = StringBuffer()
      ..writeln('📉 Analyse de l’écart (${d.periodLabel})')
      ..writeln(
        'Total non encaissé : ${JtrMobileFormatters.currency(d.gapTotal)}',
      );

    if (segs.isEmpty || d.gapTotal <= 0) {
      buf.write('Aucun écart significatif sur la période.');
      return buf.toString();
    }

    buf.writeln('Répartition :');
    for (final s in segs) {
      if (s.amount <= 0) continue;
      final share = d.gapTotal > 0 ? (s.amount / d.gapTotal) * 100 : 0.0;
      buf.writeln(
        '• ${s.label} : ${JtrMobileFormatters.currency(s.amount)} '
        '(${JtrMobileFormatters.percent(share)} de l’écart)',
      );
    }

    final top = segs.firstWhere(
      (s) => s.amount > 0,
      orElse: () => segs.first,
    );
    buf.write(
      '\nLe poste le plus important est « ${top.label} ». '
      'Ouvrez « Voir le détail par catégorie » pour les opérations.',
    );
    return buf.toString();
  }

  String _paymentsSummary(JtrDashboardData d) {
    if (d.payments.isEmpty) {
      return 'Aucun mode de paiement renseigné pour ${d.periodLabel}.';
    }
    final sorted = List<JtrPaymentBreakdownItem>.from(d.payments)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final buf = StringBuffer()
      ..writeln('💳 Modes de paiement (${d.periodLabel})');
    for (final p in sorted) {
      buf.writeln(
        '• ${p.label} : ${JtrMobileFormatters.currency(p.amount)} '
        '(${JtrMobileFormatters.percent(p.percent)})',
      );
    }
    return buf.toString().trimRight();
  }

  String _categoriesSummary(JtrDashboardData d) {
    if (d.categories.isEmpty) {
      return 'Aucune catégorie de vente pour ${d.periodLabel}.';
    }
    final sorted = List<JtrCategoryRevenue>.from(d.categories)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final buf = StringBuffer()
      ..writeln('🏷️ CA par catégorie (${d.periodLabel})');
    for (final c in sorted) {
      buf.writeln(
        '• ${c.name} : ${JtrMobileFormatters.currency(c.amount)} '
        '(${JtrMobileFormatters.percent(c.percent)})',
      );
    }
    return buf.toString().trimRight();
  }

  String _zonesSummary(JtrDashboardData d) {
    if (d.zones.isEmpty) {
      return 'Aucune zone de vente pour ${d.periodLabel}.';
    }
    final sorted = List<JtrZoneRevenue>.from(d.zones)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final buf = StringBuffer()
      ..writeln('📍 CA par zone (${d.periodLabel})');
    for (final z in sorted) {
      buf.writeln(
        '• ${z.name} : ${JtrMobileFormatters.currency(z.amount)} '
        '(${JtrMobileFormatters.percent(z.percent)})',
      );
    }
    return buf.toString().trimRight();
  }

  String _hourlySummary(JtrDashboardData d) {
    if (d.hourlyBars.isEmpty) {
      return 'Pas de données horaires pour la période.';
    }
    final peak = d.hourlyBars.where((b) => b.isPeak).toList();
    final best = peak.isNotEmpty
        ? peak.first
        : (List<JtrHourlyBar>.from(d.hourlyBars)
              ..sort((a, b) => b.amount.compareTo(a.amount)))
            .first;
    return '⏰ Affluence horaire\n'
        '• Pic : ${best.hourLabel} — '
        '${JtrMobileFormatters.currency(best.amount)}\n'
        '• ${d.peakCaption}';
  }

  String _activitySummary(JtrDashboardData d) {
    final a = d.activity;
    return '🧾 Activité (${d.periodLabel})\n'
        '• Tickets : ${JtrMobileFormatters.integer(a.tickets)} '
        '(moy. ${JtrMobileFormatters.decimal(a.avgTicket)})\n'
        '• Couverts : ${JtrMobileFormatters.integer(a.covers)} '
        '(moy. ${JtrMobileFormatters.decimal(a.avgCover)})';
  }

  String _movementsSummary(JtrDashboardData d) {
    if (d.movements.isEmpty) {
      return 'Aucun mouvement listé pour ${d.periodLabel}.';
    }
    final buf = StringBuffer()..writeln('🔁 Mouvements (${d.periodLabel})');
    for (final m in d.movements) {
      final sub = m.subValue != null ? ' (${m.subValue})' : '';
      buf.writeln('• ${m.label} : ${m.value}$sub');
    }
    return buf.toString().trimRight();
  }

  String _periodSummary(JtrDashboardData d) {
    final k = d.kpis;
    return '📅 Période sélectionnée : ${d.periodLabel}\n'
        '• Du ${JtrMobileFormatters.isoDate(d.periodFrom)} '
        'au ${JtrMobileFormatters.isoDate(d.periodTo)}\n'
        '• CA : ${JtrMobileFormatters.currency(k.revenue)}\n'
        '• Encaissé : ${JtrMobileFormatters.currency(k.collected)}\n'
        '• Tendance affichée : ${k.trendLabel}\n\n'
        'La comparaison détaillée entre deux périodes arrivera '
        'avec l’API assistant backend.';
  }
}

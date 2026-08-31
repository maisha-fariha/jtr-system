import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/payment_controller.dart';
import '../data/mappers/order_mapper.dart';
import '../utils/app_theme.dart';
import '../utils/cash_amount_input_formatter.dart';
import '../utils/responsive.dart';
import '../widgets/app_confirm_dialog.dart';

class PaymentPage extends GetView<PaymentController> {
  const PaymentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.connectBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: AppTheme.darkText,
            size: JtrResponsive.getResponsiveSize(context, 20),
          ),
          onPressed: controller.close,
        ),
        title: Text(
          'PAIEMENT',
          style: TextStyle(
            color: AppTheme.primary,
            fontSize: JtrResponsive.getResponsiveFontSize(context, 18),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }
        final err = controller.error.value;
        if (err != null && controller.modes.isEmpty) {
          return _ErrorState(
            message: err,
            onRetry: controller.load,
          );
        }
        return Column(
          children: [
            if (controller.isSubmitting.value)
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppTheme.primary,
                backgroundColor: Colors.transparent,
              ),
            Expanded(
              child: ListView(
                padding: JtrResponsive.getResponsivePadding(
                  context,
                  horizontal: 20,
                  vertical: 16,
                ),
                children: [
                  _SummaryCard(controller: controller),
                  JtrResponsive.getResponsiveSpacing(context, 16),
                  if (controller.allowPerSeat.value) ...[
                    _SeatToggle(controller: controller),
                    JtrResponsive.getResponsiveSpacing(context, 12),
                  ],
                  if (controller.perSeatTab.value)
                    _SeatList(controller: controller)
                  else
                    _LinesCard(controller: controller),
                  if (controller.transactions.isNotEmpty) ...[
                    JtrResponsive.getResponsiveSpacing(context, 16),
                    _TransactionsCard(controller: controller),
                  ],
                ],
              ),
            ),
            _PayBar(controller: controller),
          ],
        );
      }),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.controller});

  final PaymentController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Container(
        padding: JtrResponsive.getResponsivePadding(context, all: 16),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(
            JtrResponsive.getResponsiveRadius(context, 16),
          ),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              controller.ticketLabel,
              style: TextStyle(
                color: AppTheme.darkText,
                fontSize: JtrResponsive.getResponsiveFontSize(context, 16),
                fontWeight: FontWeight.w700,
              ),
            ),
            JtrResponsive.getResponsiveSpacing(context, 10),
            _kv(context, 'Total', _euro(controller.totalAmount.value)),
            _kv(context, 'Déjà payé', _euro(controller.totalPaid.value)),
            const Divider(height: 20),
            _kv(
              context,
              'Reste à payer',
              _euro(controller.remaining.value),
              emphasize: true,
            ),
          ],
        ),
      );
    });
  }

  Widget _kv(
    BuildContext context,
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: emphasize ? AppTheme.primary : AppTheme.darkText,
              fontSize: JtrResponsive.getResponsiveFontSize(
                context,
                emphasize ? 18 : 14,
              ),
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatToggle extends StatelessWidget {
  const _SeatToggle({required this.controller});

  final PaymentController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Row(
        children: [
          Expanded(
            child: _TabChip(
              label: 'Commande',
              selected: !controller.perSeatTab.value,
              onTap: () => controller.setPerSeatTab(false),
            ),
          ),
          JtrResponsive.getResponsiveHorizontalSpacing(context, 8),
          Expanded(
            child: _TabChip(
              label: 'Par couvert',
              selected: controller.perSeatTab.value,
              onTap: () => controller.setPerSeatTab(true),
            ),
          ),
        ],
      );
    });
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.primary : AppTheme.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppTheme.darkText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _SeatList extends StatelessWidget {
  const _SeatList({required this.controller});

  final PaymentController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.seatInputs.isEmpty) {
        return Text(
          'Aucun couvert dans le détail de paiement.',
          style: TextStyle(color: AppTheme.textSecondary),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Chaque couvert a son montant et son mode. '
            'Laissez vide si ce couvert ne paie pas. '
            'Le total ne doit pas dépasser le reste à payer.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: JtrResponsive.getResponsiveFontSize(context, 12),
            ),
          ),
          JtrResponsive.getResponsiveSpacing(context, 8),
          for (final input in controller.seatInputs)
            _SeatPaymentCard(controller: controller, input: input),
        ],
      );
    });
  }
}

class _SeatPaymentCard extends StatelessWidget {
  const _SeatPaymentCard({
    required this.controller,
    required this.input,
  });

  final PaymentController controller;
  final SeatPaymentInput input;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      controller.seatInputs.length;
      final cash = controller.isCashSeat(input);
      final paid = input.isFullyPaid;
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Couvert ${input.seatNumber}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkText,
                  ),
                ),
                const Spacer(),
                Text(
                  paid
                      ? 'Payé'
                      : (input.suggestedAmount > 0
                          ? 'Part ${_euro(input.suggestedAmount)}'
                          : ''),
                  style: TextStyle(
                    color: paid ? AppTheme.textSecondary : AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
                  ),
                ),
              ],
            ),
            if (!paid) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < controller.modes.length; i++)
                    Builder(
                      builder: (_) {
                        final mode = controller.modes[i];
                        final id = OrderMapper.paymentModeId(mode) ?? 0;
                        final selected = input.modeId == id;
                        final color = OrderMapper.paymentModeColorForIndex(i);
                        return ChoiceChip(
                          label: Text(mode['name']?.toString() ?? 'Mode'),
                          selected: selected,
                          showCheckmark: false,
                          selectedColor: color,
                          backgroundColor: color.withValues(alpha: 0.12),
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : AppTheme.darkText,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) =>
                              controller.setSeatMode(input.seatNumber, id),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: input.amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                  ZeroAmountBackspaceClearFormatter(),
                ],
                decoration: InputDecoration(
                  labelText: 'Montant',
                  hintText: 'Vide = ne paie pas',
                  suffixText: '€',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (cash) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: input.givenController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                    ZeroAmountBackspaceClearFormatter(),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Montant donné',
                    hintText: 'Espèces reçues',
                    suffixText: '€',
                    helperText: 'Moins = partiel · Plus = rendu',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 10),
                TextField(
                  controller: input.referenceController,
                  decoration: InputDecoration(
                    labelText: 'Référence (optionnel)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      );
    });
  }
}

class _LinesCard extends StatelessWidget {
  const _LinesCard({required this.controller});

  final PaymentController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < controller.lines.length; i++)
            _LineEditor(
              controller: controller,
              index: i,
              line: controller.lines[i],
            ),
          if (controller.allowMultiple.value && !controller.isFullyPaid.value)
            TextButton.icon(
              onPressed: controller.addSplitLine,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un mode (split)'),
            ),
        ],
      );
    });
  }
}

class _LineEditor extends StatelessWidget {
  const _LineEditor({
    required this.controller,
    required this.index,
    required this.line,
  });

  final PaymentController controller;
  final int index;
  final PaymentLineInput line;

  @override
  Widget build(BuildContext context) {
    final cash = controller.isCashLine(line);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Mode ${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkText,
                ),
              ),
              const Spacer(),
              if (controller.lines.length > 1)
                IconButton(
                  onPressed: () => controller.removeLine(index),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < controller.modes.length; i++)
                Builder(
                  builder: (_) {
                    final mode = controller.modes[i];
                    final id = OrderMapper.paymentModeId(mode) ?? 0;
                    final selected = line.modeId == id;
                    final color = OrderMapper.paymentModeColorForIndex(i);
                    return ChoiceChip(
                      label: Text(mode['name']?.toString() ?? 'Mode'),
                      selected: selected,
                      showCheckmark: false,
                      selectedColor: color,
                      backgroundColor: color.withValues(alpha: 0.12),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppTheme.darkText,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => controller.setLineMode(index, id),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: line.amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
              ZeroAmountBackspaceClearFormatter(),
            ],
            decoration: InputDecoration(
              labelText: 'Montant',
              suffixText: '€',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (cash) ...[
            const SizedBox(height: 10),
            TextField(
              controller: line.givenController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ZeroAmountBackspaceClearFormatter(),
              ],
              decoration: InputDecoration(
                labelText: 'Montant donné',
                hintText: 'Espèces reçues (ex. 50 si rendu)',
                suffixText: '€',
                helperText:
                    'Si moins que le montant → paiement partiel. '
                    'Si plus → rendu (change).',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            TextField(
              controller: line.referenceController,
              decoration: InputDecoration(
                labelText: 'Référence (optionnel)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TransactionsCard extends StatelessWidget {
  const _TransactionsCard({required this.controller});

  final PaymentController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transactions',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 8),
            for (final tx in controller.transactions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  _txLabel(tx),
                  style: TextStyle(color: AppTheme.darkText),
                ),
                subtitle: Text(
                  tx['status']?.toString() ?? '',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                trailing: controller.canCancelTransaction
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          final id = (tx['id'] as num?)?.toInt();
                          if (id == null) return;
                          AppConfirmDialog.show(
                            context: context,
                            title: 'Annuler',
                            message: 'Annuler cette transaction ?',
                            onConfirm: () => controller.cancelTransaction(id),
                          );
                        },
                      )
                    : null,
              ),
          ],
        ),
      );
    });
  }

  String _txLabel(Map<String, dynamic> tx) {
    final mode = tx['payment_mode'];
    final name = mode is Map ? mode['name']?.toString() : null;
    final amount = tx['amount'];
    return '${name ?? 'Paiement'}  ${_euro(_asDouble(amount) ?? 0)}';
  }
}

class _PayBar extends StatelessWidget {
  const _PayBar({required this.controller});

  final PaymentController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final disabled = controller.isSubmitting.value ||
          controller.isFullyPaid.value ||
          controller.remaining.value <= 0;
      return SafeArea(
        top: false,
        child: Padding(
          padding: JtrResponsive.getResponsivePadding(
            context,
            left: 20,
            right: 20,
            top: 8,
            bottom: 16,
          ),
          child: SizedBox(
            height: JtrResponsive.getResponsiveHeight(context, 56),
            width: double.infinity,
            child: ElevatedButton(
              onPressed: disabled ? null : controller.submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.inactiveSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: controller.isSubmitting.value
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      controller.isFullyPaid.value
                          ? 'DÉJÀ PAYÉ'
                          : 'ENCAISSER',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
            ),
          ),
        ),
      );
    });
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

String _euro(double value) =>
    '${value.toStringAsFixed(2).replaceAll('.', ',')} €';

double? _asDouble(dynamic raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) {
    return double.tryParse(raw.replaceAll(',', '.').replaceAll('€', '').trim());
  }
  return null;
}

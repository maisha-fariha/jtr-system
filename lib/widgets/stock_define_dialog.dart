import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../utils/app_theme.dart';
import '../utils/responsive.dart';

enum StockDefineAction {
  cancel,
  save,
  removeTracking,
  block,
}

class StockDefineResult {
  const StockDefineResult({
    required this.action,
    this.quantity,
    this.removeTracking = false,
  });

  final StockDefineAction action;
  final int? quantity;
  final bool removeTracking;
}

/// Manager modal: Définir le Stock.
class StockDefineDialog extends StatefulWidget {
  const StockDefineDialog({
    super.key,
    required this.productName,
    required this.initialQuantity,
  });

  final String productName;
  final int initialQuantity;

  static Future<StockDefineResult?> show({
    required String productName,
    required int initialQuantity,
    BuildContext? context,
  }) {
    final dialogContext = context ?? Get.overlayContext ?? Get.context;
    if (dialogContext == null || !dialogContext.mounted) {
      return Future.value();
    }

    return showDialog<StockDefineResult>(
      context: dialogContext,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: AppTheme.dialogBarrier,
      builder: (_) => StockDefineDialog(
        productName: productName,
        initialQuantity: initialQuantity,
      ),
    );
  }

  @override
  State<StockDefineDialog> createState() => _StockDefineDialogState();
}

class _StockDefineDialogState extends State<StockDefineDialog> {
  late final TextEditingController _qtyController;
  bool _removeTracking = false;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
      text: widget.initialQuantity > 0 ? '${widget.initialQuantity}' : '',
    );
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  void _pop(StockDefineResult result) {
    Navigator.of(context, rootNavigator: true).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final radius = JtrResponsive.getResponsiveRadius(context, 20);
    final saveLabel =
        _removeTracking ? 'Supprimer le stock' : 'Enregistrer';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: JtrResponsive.getResponsivePadding(
        context,
        horizontal: 28,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.dialogBackground,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Padding(
          padding: JtrResponsive.getResponsivePadding(context, all: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Définir le Stock',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: JtrResponsive.getResponsiveFontSize(context, 18),
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkText,
                ),
              ),
              JtrResponsive.getResponsiveSpacing(context, 6),
              Text(
                widget.productName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: JtrResponsive.getResponsiveFontSize(context, 14),
                  color: AppTheme.textSecondary,
                ),
              ),
              JtrResponsive.getResponsiveSpacing(context, 16),
              TextField(
                controller: _qtyController,
                enabled: !_removeTracking,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(5),
                ],
                decoration: InputDecoration(
                  labelText: 'Quantité',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      JtrResponsive.getResponsiveRadius(context, 10),
                    ),
                  ),
                ),
              ),
              JtrResponsive.getResponsiveSpacing(context, 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _removeTracking,
                onChanged: (value) {
                  setState(() => _removeTracking = value ?? false);
                },
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'Supprimer le suivi de stock…',
                  style: TextStyle(
                    fontSize:
                        JtrResponsive.getResponsiveFontSize(context, 13),
                    color: AppTheme.darkText,
                  ),
                ),
              ),
              JtrResponsive.getResponsiveSpacing(context, 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pop(
                        const StockDefineResult(
                          action: StockDefineAction.cancel,
                        ),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  JtrResponsive.getResponsiveHorizontalSpacing(context, 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pop(
                        const StockDefineResult(
                          action: StockDefineAction.block,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC0392B),
                      ),
                      child: const Text('Bloquer'),
                    ),
                  ),
                ],
              ),
              JtrResponsive.getResponsiveSpacing(context, 10),
              ElevatedButton(
                onPressed: () {
                  if (_removeTracking) {
                    _pop(
                      const StockDefineResult(
                        action: StockDefineAction.removeTracking,
                        removeTracking: true,
                      ),
                    );
                    return;
                  }
                  final qty = int.tryParse(_qtyController.text.trim());
                  if (qty == null || qty < 1) {
                    // Backend daily_limit is 1–1000; use Bloquer for 0.
                    return;
                  }
                  final clamped = qty > 1000 ? 1000 : qty;
                  _pop(
                    StockDefineResult(
                      action: StockDefineAction.save,
                      quantity: clamped,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: JtrResponsive.getResponsivePadding(
                    context,
                    vertical: 14,
                  ),
                ),
                child: Text(saveLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

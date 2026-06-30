import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/catalog/catalog_product_model.dart';
import '../utils/app_theme.dart';

typedef ComposedProductConfirm = void Function(
  List<Map<String, dynamic>> menuSelections,
);

class ComposedProductPickerSheet extends StatefulWidget {
  const ComposedProductPickerSheet({
    super.key,
    required this.product,
    required this.onConfirm,
  });

  final CatalogProductModel product;
  final ComposedProductConfirm onConfirm;

  static Future<void> show({
    required CatalogProductModel product,
    required ComposedProductConfirm onConfirm,
  }) {
    return Get.bottomSheet(
      ComposedProductPickerSheet(product: product, onConfirm: onConfirm),
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
  }

  @override
  State<ComposedProductPickerSheet> createState() =>
      _ComposedProductPickerSheetState();
}

class _ComposedProductPickerSheetState extends State<ComposedProductPickerSheet> {
  final Map<int, ProductMenuOptionModel> _selections = {};

  bool get _isValid {
    for (final category in widget.product.menuCategories) {
      if (!category.isRequired) continue;
      final selected = _selections[category.id];
      if (selected == null) return false;
    }
    return widget.product.menuCategories.isNotEmpty;
  }

  double get _totalPrice {
    var total = widget.product.unitPrice;
    for (final selection in _selections.values) {
      total += selection.supplement;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: Get.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.product.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkText,
                        ),
                      ),
                    ),
                    Text(
                      '${_totalPrice.toStringAsFixed(2).replaceAll('.', ',')} €',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  itemCount: widget.product.menuCategories.length,
                  itemBuilder: (context, index) {
                    final category = widget.product.menuCategories[index];
                    final selected = _selections[category.id];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: category.products.map((option) {
                              final isSelected = selected?.id == option.id;
                              final supplement = option.supplement;
                              final label = supplement > 0
                                  ? '${option.name} (+${supplement.toStringAsFixed(2).replaceAll('.', ',')} €)'
                                  : option.name;

                              return ChoiceChip(
                                label: Text(label),
                                selected: isSelected,
                                onSelected: (_) {
                                  setState(() {
                                    _selections[category.id] = option;
                                  });
                                },
                                selectedColor:
                                    AppTheme.primary.withValues(alpha: 0.15),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? AppTheme.primary
                                      : AppTheme.darkText,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _isValid ? _confirm : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      disabledBackgroundColor: const Color(0xFFE0E0E0),
                    ),
                    child: const Text('AJOUTER'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirm() {
    final selections = <Map<String, dynamic>>[];
    for (final category in widget.product.menuCategories) {
      final option = _selections[category.id];
      if (option == null) continue;
      selections.add({
        'menu_category_id': category.id,
        'selected_product_id': option.id,
        'price': option.supplement,
        'menu_category_name': category.name,
        'selected_product_name': option.name,
      });
    }
    Get.back();
    widget.onConfirm(selections);
  }
}

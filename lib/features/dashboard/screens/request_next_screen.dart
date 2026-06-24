import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/dashboard_data.dart';

/// Screen to request the next course for an active table.
class RequestNextScreen extends StatefulWidget {
  const RequestNextScreen({
    super.key,
    this.tableNumber,
  });

  final String? tableNumber;

  @override
  State<RequestNextScreen> createState() => _RequestNextScreenState();
}

class _RequestNextScreenState extends State<RequestNextScreen> {
  late String _selectedTable;

  @override
  void initState() {
    super.initState();
    final activeOrders = DashboardData.activeOrders();
    _selectedTable = widget.tableNumber ??
        (activeOrders.isNotEmpty
            ? activeOrders.first.tableNumber
            : DashboardData.availableTables.first);
  }

  @override
  Widget build(BuildContext context) {
    final activeTables = DashboardData.activeOrders();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.requestNextTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.sp24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.requestNextDescription, style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppConstants.sp24),
            if (activeTables.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    AppStrings.noActiveTables,
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: activeTables.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppConstants.sp8),
                  itemBuilder: (context, index) {
                    final order = activeTables[index];
                    final isSelected = order.tableNumber == _selectedTable;

                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: AppColors.primary.withValues(alpha: 0.15),
                      tileColor: AppColors.cardOverlay,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.borderSubtle,
                        ),
                      ),
                      title: Text(
                        order.tableNumber,
                        style: AppTextStyles.titleLarge.copyWith(
                          color: order.tableColor,
                        ),
                      ),
                      subtitle: Text(
                        '${order.guests} ${AppStrings.guestsLabel} · ${order.formattedTotal}',
                        style: AppTextStyles.bodySmall,
                      ),
                      onTap: () {
                        setState(() => _selectedTable = order.tableNumber);
                      },
                    );
                  },
                ),
              ),
            PrimaryButton(
              label: AppStrings.sendRequest,
              onPressed: activeTables.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).pop(_selectedTable);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${AppStrings.requestSent} $_selectedTable',
                          ),
                        ),
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }
}

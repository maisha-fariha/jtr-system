import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import '../controllers/session_controller.dart';
import '../models/session_order.dart';
import '../utils/app_theme.dart';

class SessionPage extends GetView<SessionController> {
  const SessionPage({super.key});

  static const _orderSlidableGroupTag = 'session-orders';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _SessionHeader(controller: controller),
            _ActionButtons(controller: controller),
            Expanded(child: _OrderList(controller: controller)),
            _SessionFooter(controller: controller),
          ],
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.controller});
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: AppTheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: Get.back,
            child:
                const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Text('SESSION',
              style: AppTheme.title1
                  .copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const Spacer(),
          Obx(() => Text(
                '${controller.orders.length} table${controller.orders.length != 1 ? 's' : ''}',
                style: AppTheme.body2.copyWith(color: Colors.white70),
              )),
        ],
      ),
    );
  }
}

// ── Action buttons ─────────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.controller});
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Obx(() => Row(
            children: [
              _ActionButton(
                label: 'NOUVELLE\nCOMMANDE',
                icon: Icons.add_circle_outline,
                isActive: controller.selectedAction.value ==
                    SessionAction.nouvelleCommande,
                onTap: controller.showTableNumberDialog,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                label: 'VALIDER\nCOMMANDE',
                icon: Icons.check_circle_outline,
                isActive: controller.selectedAction.value ==
                    SessionAction.validerCommande,
                onTap: () =>
                    controller.selectAction(SessionAction.validerCommande),
              ),
              const SizedBox(width: 8),
              _ActionButton(
                label: 'IMPRIMER',
                icon: Icons.print_outlined,
                isActive: controller.selectedAction.value ==
                    SessionAction.imprimer,
                onTap: () =>
                    controller.selectAction(SessionAction.imprimer),
              ),
            ],
          )),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 64,
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primary
                : AppTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? AppTheme.primary
                  : AppTheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 20,
                  color: isActive ? Colors.white : AppTheme.primary),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : AppTheme.primary,
                  letterSpacing: 0.5,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Order list ─────────────────────────────────────────────────────────────────

class _OrderList extends StatelessWidget {
  const _OrderList({required this.controller});
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.orders.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.receipt_long_outlined,
                  size: 56, color: AppTheme.border),
              const SizedBox(height: 12),
              Text('Aucune commande active',
                  style: AppTheme.body1
                      .copyWith(color: AppTheme.textLight)),
            ],
          ),
        );
      }

      return SlidableAutoCloseBehavior(
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: controller.orders.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final order = controller.orders[index];
            return Slidable(
              key: ValueKey(order.number),
              groupTag: SessionPage._orderSlidableGroupTag,
              startActionPane: ActionPane(
                motion: const ScrollMotion(),
                extentRatio: 0.18,
                children: [
                  SlidableAction(
                    onPressed: (_) =>
                        controller.requestDeleteOrder(order.number),
                    backgroundColor: AppTheme.background,
                    foregroundColor: AppTheme.error,
                    icon: Icons.delete_outline,
                    spacing: 0,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              endActionPane: ActionPane(
                motion: const ScrollMotion(),
                extentRatio: 0.18,
                children: [
                  SlidableAction(
                    onPressed: (_) =>
                        controller.requestApplyOffer(order.number),
                    backgroundColor: AppTheme.background,
                    foregroundColor: AppTheme.primary,
                    icon: Icons.local_offer_outlined,
                    spacing: 0,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              child: _OrderRow(
                order: order,
                onTap: () =>
                    controller.toggleOrderExpansion(order.number),
              ),
            );
          },
        ),
      );
    });
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.onTap});

  final SessionOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: order.isSelected ? AppTheme.primary : AppTheme.border),
          boxShadow: AppTheme.subtleShadow,
        ),
        child: Column(
          children: [
            // Summary row
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Table badge
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${order.tableNumber}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Table ${order.tableNumber}',
                          style: AppTheme.title2,
                        ),
                        Text(
                          '${order.itemCount} article${order.itemCount != 1 ? 's' : ''}',
                          style: AppTheme.body2,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${order.total.toStringAsFixed(0)} MAD',
                        style: AppTheme.title2
                            .copyWith(color: AppTheme.primary),
                      ),
                      Text(order.number, style: AppTheme.caption),
                    ],
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: order.isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: AppTheme.textLight),
                  ),
                ],
              ),
            ),

            // Expanded product list
            if (order.isExpanded) ...[
              const Divider(height: 1),
              ...order.products.map((product) => Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          'x${product.quantity}',
                          style: AppTheme.body2.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child:
                                Text(product.name, style: AppTheme.body1)),
                        Text(
                          '${product.totalPrice.toStringAsFixed(0)} MAD',
                          style: AppTheme.body2,
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Footer ─────────────────────────────────────────────────────────────────────

class _SessionFooter extends StatelessWidget {
  const _SessionFooter({required this.controller});
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TOTAL SESSION', style: AppTheme.label),
              const SizedBox(height: 2),
              Obx(() => Text(
                    '${controller.sessionTotal.toStringAsFixed(0)} MAD',
                    style: AppTheme.headline2
                        .copyWith(color: AppTheme.primary),
                  )),
            ],
          ),
          const Spacer(),
          Obx(() => Text(
                '${controller.orders.length} commande${controller.orders.length != 1 ? 's' : ''}',
                style: AppTheme.body2,
              )),
        ],
      ),
    );
  }
}

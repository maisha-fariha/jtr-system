import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../models/table_order.dart';
import '../widgets/session_header.dart';
import '../widgets/order_table.dart';
import '../widgets/footer_action_buttons.dart';
import '../widgets/bottom_nav_bar.dart';

/// Main dashboard / order-management screen.
/// Figma: "Html → Body" (frame 31:1466)
///
/// Layout:
///   ┌──────────────────────────────────────────┐
///   │  [Session Header — circle, role, date]   │ 80px
///   ├──────────────────────────────────────────┤
///   │  N°  G.  POSTE  CTR. CVT. IMP. TOTAL     │ 48px header
///   ├──────────────────────────────────────────┤
///   │  [T5 row]                                │  ↕
///   │  [T6 row]                                │  scrollable
///   │  ...                                     │
///   ├──────────────────────────────────────────┤
///   │  [NOUVELLE COMMANDE][SUITE][TICKET][STAT]│ 142px
///   ├──────────────────────────────────────────┤
///   │  [🏠]        [↩]           [→|]          │ 57px
///   └──────────────────────────────────────────┘
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _navIndex = 0;

  // ── Sample data matching the Figma mockup ──────────────────────────────────
  final List<TableOrder> _orders = const [
    TableOrder(
      tableNumber: 'T5',
      guests: 1,
      post: 'POC1',
      serviceType: 'SUR PLACE',
      covers: 0,
      imprimes: 0,
      total: 630.00,
      isActive: true,
    ),
    TableOrder(
      tableNumber: 'T6',
      guests: 1,
      post: 'POC1',
      serviceType: 'SUR PLACE',
      covers: 0,
      imprimes: 1,
      total: 950.00,
      isActive: false,
    ),
  ];

  String get _formattedDate {
    return DateFormat("EEEE d MMMM yyyy", "fr_FR")
        .format(DateTime.now())
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Session header ────────────────────────────────────────────
            SessionHeader(
              sessionNumber: 1,
              role: AppStrings.roleLabelManager,
              date: _formattedDate,
              serviceType: AppStrings.surPlace,
            ),

            // ── Orders table (scrollable) ────────────────────────────────
            Expanded(
              child: OrderTable(
                orders: _orders,
                onRowTap: (order) => _showOrderDetail(order),
              ),
            ),

            // ── Footer action buttons ─────────────────────────────────────
            FooterActionButtons(
              onNewOrder: _onNewOrder,
              onRequestNext: _onRequestNext,
              onTicket: _onTicket,
              onStatistics: _onStatistics,
            ),

            // ── Bottom navigation bar ─────────────────────────────────────
            DashboardBottomNavBar(
              currentIndex: _navIndex,
              onTap: (index) => setState(() => _navIndex = index),
            ),
          ],
        ),
      ),
    );
  }

  // ── Action handlers ──────────────────────────────────────────────────────

  void _onNewOrder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nouvelle commande')),
    );
  }

  void _onRequestNext() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Demander la suite')),
    );
  }

  void _onTicket() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ticket')),
    );
  }

  void _onStatistics() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Statistics')),
    );
  }

  void _showOrderDetail(TableOrder order) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _OrderDetailSheet(order: order),
    );
  }
}

/// Minimal bottom-sheet placeholder for order detail.
class _OrderDetailSheet extends StatelessWidget {
  const _OrderDetailSheet({required this.order});

  final TableOrder order;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                order.tableNumber,
                style: TextStyle(
                  fontFamily: 'HankenGrotesk',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: order.tableColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${order.guests} guest(s) · ${order.post} · ${order.serviceType}',
                style: const TextStyle(
                  fontFamily: 'HankenGrotesk',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Total: ${order.formattedTotal}',
            style: const TextStyle(
              fontFamily: 'HankenGrotesk',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

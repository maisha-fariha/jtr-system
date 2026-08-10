import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/customer_info.dart';
import '../data/repositories/customer_repository.dart';
import '../core/network/api_exception.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';

/// Pick or create a cardex customer before opening a free-zone order.
class CustomerCardexDialog extends StatefulWidget {
  const CustomerCardexDialog({
    super.key,
    required this.onSelected,
  });

  final ValueChanged<CustomerInfo> onSelected;

  static Future<void> show({
    required ValueChanged<CustomerInfo> onSelected,
    BuildContext? context,
  }) {
    final dialogContext = context ?? Get.overlayContext ?? Get.context;
    if (dialogContext == null || !dialogContext.mounted) {
      return Future.value();
    }
    return showModalBottomSheet<void>(
      context: dialogContext,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(
            JtrResponsive.getResponsiveRadius(dialogContext, 20),
          ),
        ),
      ),
      builder: (_) => CustomerCardexDialog(onSelected: onSelected),
    );
  }

  @override
  State<CustomerCardexDialog> createState() => _CustomerCardexDialogState();
}

class _CustomerCardexDialogState extends State<CustomerCardexDialog> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  List<CustomerInfo> _customers = const [];
  var _loading = true;
  var _creating = false;
  var _showCreate = false;
  String? _error;
  Timer? _debounce;

  CustomerRepository get _repo => Get.find<CustomerRepository>();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _load({String? query}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.getShortlist(
        query: query,
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() {
        _customers = list;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _customers = _repo.cachedShortlist;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les clients.';
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      unawaited(_load(query: value));
    });
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Le nom du client est requis.');
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final created = await _repo.createCustomer(
        name: name,
        phoneNumber: _phoneController.text.trim(),
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSelected(created);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _creating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de créer le client.';
        _creating = false;
      });
    }
  }

  void _pick(CustomerInfo customer) {
    Navigator.of(context).pop();
    widget.onSelected(customer);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.82;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: EdgeInsets.only(
                    top: JtrResponsive.getResponsiveSize(context, 10),
                  ),
                  width: JtrResponsive.getResponsiveSize(context, 40),
                  height: JtrResponsive.getResponsiveSize(context, 4),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBorder,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Padding(
                padding: JtrResponsive.getResponsivePadding(
                  context,
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _showCreate ? 'Nouveau client' : 'Client (cardex)',
                        style: TextStyle(
                          fontSize:
                              JtrResponsive.getResponsiveFontSize(context, 18),
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkText,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _creating
                          ? null
                          : () => setState(() {
                                _showCreate = !_showCreate;
                                _error = null;
                              }),
                      child: Text(
                        _showCreate ? 'Liste' : 'Créer',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: JtrResponsive.getResponsivePadding(
                    context,
                    horizontal: 20,
                    vertical: 0,
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize:
                          JtrResponsive.getResponsiveFontSize(context, 12),
                    ),
                  ),
                ),
              Flexible(
                child: _showCreate
                    ? SingleChildScrollView(child: _buildCreateForm(context))
                    : _buildList(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    return Column(
      children: [
          Padding(
            padding: JtrResponsive.getResponsivePadding(
              context,
              horizontal: 16,
              vertical: 8,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Rechercher un client…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppTheme.inactiveSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    JtrResponsive.getResponsiveRadius(context, 12),
                  ),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            )
          else if (_customers.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'Aucun client',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: JtrResponsive.getResponsivePadding(
                  context,
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: _customers.length,
                separatorBuilder: (_, __) => SizedBox(
                  height: JtrResponsive.getResponsiveSize(context, 8),
                ),
                itemBuilder: (_, index) {
                  final customer = _customers[index];
                  return Material(
                    color: AppTheme.inactiveSurface,
                    borderRadius: BorderRadius.circular(
                      JtrResponsive.getResponsiveRadius(context, 12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(
                        JtrResponsive.getResponsiveRadius(context, 12),
                      ),
                      onTap: () => _pick(customer),
                      child: Padding(
                        padding: JtrResponsive.getResponsivePadding(
                          context,
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkText,
                                fontSize: JtrResponsive.getResponsiveFontSize(
                                  context,
                                  14,
                                ),
                              ),
                            ),
                            if (customer.subtitle.isNotEmpty) ...[
                              SizedBox(
                                height:
                                    JtrResponsive.getResponsiveSize(context, 4),
                              ),
                              Text(
                                customer.subtitle,
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize:
                                      JtrResponsive.getResponsiveFontSize(
                                    context,
                                    12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
    );
  }

  Widget _buildCreateForm(BuildContext context) {
    return Padding(
      padding: JtrResponsive.getResponsivePadding(
        context,
        horizontal: 16,
        vertical: 8,
      ),
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nom *',
              border: OutlineInputBorder(),
            ),
          ),
          JtrResponsive.getResponsiveSpacing(context, 10),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Téléphone',
              border: OutlineInputBorder(),
            ),
          ),
          JtrResponsive.getResponsiveSpacing(context, 10),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          JtrResponsive.getResponsiveSpacing(context, 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _creating ? null : _create,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: JtrResponsive.getResponsiveSize(context, 14),
                ),
              ),
              child: _creating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Créer et sélectionner',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          JtrResponsive.getResponsiveSpacing(context, 12),
        ],
      ),
    );
  }
}

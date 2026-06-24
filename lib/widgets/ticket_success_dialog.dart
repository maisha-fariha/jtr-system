import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/app_theme.dart';

class TicketSuccessDialog extends StatefulWidget {
  const TicketSuccessDialog({super.key});

  @override
  State<TicketSuccessDialog> createState() => _TicketSuccessDialogState();
}

class _TicketSuccessDialogState extends State<TicketSuccessDialog> {
  static const _initialSeconds = 3;

  int _secondsRemaining = _initialSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsRemaining <= 1) {
        _timer?.cancel();
        if (mounted) Get.back();
        return;
      }
      setState(() => _secondsRemaining--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppTheme.lightButton,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: AppTheme.primary,
                size: 30,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "L'impression a été effectuée sur l'imprimante principale TICKET.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Get.back(),
                child: Text(
                  'OK (${_secondsRemaining}S)',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

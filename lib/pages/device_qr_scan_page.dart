import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/app_theme.dart';
import '../utils/responsive.dart';

/// Full-screen camera QR scan. Returns scanned text via [Get.back].
class DeviceQrScanPage extends StatefulWidget {
  const DeviceQrScanPage({super.key});

  @override
  State<DeviceQrScanPage> createState() => _DeviceQrScanPageState();
}

class _DeviceQrScanPageState extends State<DeviceQrScanPage>
    with WidgetsBindingObserver {
  final MobileScannerController _scanner = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _handled = false;
  bool _permissionReady = false;
  bool _permissionDenied = false;
  bool _permanentlyDenied = false;
  bool _checkingPermission = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ensureCameraPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanner.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (_permissionDenied || _permanentlyDenied)) {
      _ensureCameraPermission();
    }
  }

  Future<void> _ensureCameraPermission() async {
    setState(() {
      _checkingPermission = true;
      _permissionDenied = false;
      _permanentlyDenied = false;
    });

    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }

    if (!mounted) return;

    if (status.isGranted) {
      setState(() {
        _permissionReady = true;
        _permissionDenied = false;
        _permanentlyDenied = false;
        _checkingPermission = false;
      });
      try {
        await _scanner.start();
      } catch (_) {
        // errorBuilder on MobileScanner will show details
      }
      return;
    }

    setState(() {
      _permissionReady = false;
      _permissionDenied = true;
      _permanentlyDenied = status.isPermanentlyDenied;
      _checkingPermission = false;
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;
      _handled = true;
      _scanner.stop();
      Get.back(result: raw);
      return;
    }
  }

  Widget _permissionDeniedPanel() {
    final message = _permanentlyDenied
        ? 'Permission caméra refusée. Activez-la dans les réglages de l’appareil.'
        : 'Permission caméra refusée. Autorisez l’accès pour scanner le QR.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_photography_outlined,
              color: Colors.white.withValues(alpha: 0.9),
              size: JtrResponsive.getResponsiveSize(context, 48),
            ),
            JtrResponsive.getResponsiveSpacing(context, 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: JtrResponsive.getResponsiveFontSize(context, 15),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            JtrResponsive.getResponsiveSpacing(context, 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: _permanentlyDenied
                  ? openAppSettings
                  : _ensureCameraPermission,
              child: Text(
                _permanentlyDenied ? 'Ouvrir les réglages' : 'Réessayer',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scannerErrorBuilder(
    BuildContext context,
    MobileScannerException error,
  ) {
    final isDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 40),
            const SizedBox(height: 12),
            Text(
              isDenied
                  ? 'Permission caméra refusée.'
                  : 'Impossible d’ouvrir la caméra.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: JtrResponsive.getResponsiveFontSize(context, 15),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (isDenied) {
                  final status = await Permission.camera.status;
                  if (status.isPermanentlyDenied) {
                    await openAppSettings();
                  } else {
                    await _ensureCameraPermission();
                  }
                } else {
                  await _ensureCameraPermission();
                }
              },
              child: Text(
                isDenied ? 'Autoriser / Réglages' : 'Réessayer',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          'Scanner le QR',
          style: TextStyle(
            fontSize: JtrResponsive.getResponsiveFontSize(context, 18),
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (_permissionReady)
            IconButton(
              tooltip: 'Lampe',
              onPressed: () => _scanner.toggleTorch(),
              icon: const Icon(Icons.flash_on),
            ),
        ],
      ),
      body: _checkingPermission
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : _permissionDenied
              ? _permissionDeniedPanel()
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _scanner,
                      onDetect: _onDetect,
                      errorBuilder: _scannerErrorBuilder,
                    ),
                    Center(
                      child: Container(
                        width: JtrResponsive.getResponsiveSize(context, 240),
                        height: JtrResponsive.getResponsiveSize(context, 240),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppTheme.primary,
                            width: 2.5,
                          ),
                          borderRadius: BorderRadius.circular(
                            JtrResponsive.getResponsiveRadius(context, 16),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 48,
                      child: Text(
                        'Placez le QR du dashboard Windows dans le cadre',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: JtrResponsive.getResponsiveFontSize(
                            context,
                            14,
                          ),
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/config/api_config.dart';
import '../core/network/api_exception.dart';
import '../data/mappers/device_activation_mapper.dart';
import '../data/repositories/device_repository.dart';
import '../routes/app_pages.dart';

/// TODO: set to `false` when `/api/devices/*` is deployed.
const bool kBypassDeviceActivation = true;

class DeviceActivationController extends GetxController {
  DeviceActivationController({required DeviceRepository deviceRepository})
      : _deviceRepository = deviceRepository;

  final DeviceRepository _deviceRepository;

  final codeController = TextEditingController();
  final tenantController = TextEditingController();

  final isSubmitting = false.obs;
  final isImportingQr = false.obs;
  final errorMessage = RxnString();
  final importedApiBaseUrl = RxnString();

  @override
  void onClose() {
    codeController.dispose();
    tenantController.dispose();
    super.onClose();
  }

  Future<void> importQrPng() async {
    errorMessage.value = null;
    isImportingQr.value = true;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;
      late final String qrText;
      if (bytes != null && bytes.isNotEmpty) {
        qrText = _deviceRepository.decodeQrImageBytes(bytes);
      } else if (file.path != null) {
        qrText = await _deviceRepository.decodeQrImageFile(File(file.path!));
      } else {
        throw ApiException(message: 'Fichier QR inaccessible.');
      }

      final payload = DeviceActivationMapper.parseQrText(qrText);
      codeController.text = payload.code;
      tenantController.text = payload.tenantSchema;
      importedApiBaseUrl.value = payload.apiBaseUrl;
    } on ApiException catch (e) {
      errorMessage.value = e.message;
    } on FormatException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Impossible d\'importer le QR.';
    } finally {
      isImportingQr.value = false;
    }
  }

  Future<void> activate() async {
    errorMessage.value = null;

    // Temporary: device activate API is not deployed yet.
    if (kBypassDeviceActivation) {
      debugPrint(
        '════════ DEVICE ACTIVATE BYPASS → ${AppRoutes.connect} ════════',
      );
      Get.offAllNamed(AppRoutes.connect);
      return;
    }

    final code = DeviceActivationMapper.normalizeCode(codeController.text);
    final tenant =
        DeviceActivationMapper.normalizeTenantSchema(tenantController.text);

    if (code.length < 8) {
      errorMessage.value = 'Saisissez un code d\'activation valide.';
      return;
    }
    if (tenant.isEmpty) {
      errorMessage.value = 'Saisissez le schéma restaurant.';
      return;
    }

    isSubmitting.value = true;
    try {
      await _deviceRepository.activateWithCode(
        code: code,
        tenantSchema: tenant,
        apiBaseUrl: importedApiBaseUrl.value ??
            '${ApiConfig.normalizeOriginBaseUrl(ApiConfig.defaultBaseUrl)}/api',
      );
      Get.offAllNamed(AppRoutes.connect);
    } on ApiException catch (e) {
      errorMessage.value = e.message;
    } on FormatException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Activation impossible. Réessayez.';
    } finally {
      isSubmitting.value = false;
    }
  }
}

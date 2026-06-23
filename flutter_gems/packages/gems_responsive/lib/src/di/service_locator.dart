import 'package:get_it/get_it.dart';
import 'package:flutter/material.dart';

/// Service Locator instance for gems_responsive
/// This can be used to register responsive-related services if needed
final responsiveGetIt = GetIt.instance;

/// Initialize responsive services (currently minimal, but can be extended)
/// 
/// Usage:
/// ```dart
/// setupResponsiveServices();
/// ```
void setupResponsiveServices() {
  // Currently no services to register, but this provides a consistent
  // pattern for future responsive-related services
  // Example: Theme service, Breakpoint service, etc.
}

/// Reset responsive services (useful for testing)
Future<void> resetResponsiveServices() async {
  await responsiveGetIt.reset();
}

/// Register a responsive service
/// 
/// Example:
/// ```dart
/// registerResponsiveService<ThemeService>(ThemeService());
/// ```
void registerResponsiveService<T extends Object>(T instance) {
  responsiveGetIt.registerSingleton<T>(instance);
}

/// Get a responsive service
/// 
/// Example:
/// ```dart
/// final themeService = getResponsiveService<ThemeService>();
/// ```
T getResponsiveService<T extends Object>() {
  return responsiveGetIt<T>();
}


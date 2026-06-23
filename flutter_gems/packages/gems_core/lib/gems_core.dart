/// Flutter Gems Core Package
///
/// Core utilities for Flutter apps including:
/// - Result types for error handling
/// - Environment configuration
/// - Input validation
/// - Extensions and helpers
library gems_core;

// Result Types
export 'src/result/result.dart';
export 'src/result/app_error.dart';

// Configuration
export 'src/config/environment.dart';

// Validation
export 'src/validation/validators.dart';

// Dependency Injection
export 'src/di/service_locator.dart';

// Extensions
export 'src/extensions/result_extensions.dart';
export 'src/extensions/string_extensions.dart';

// Helpers
export 'src/helpers/use_case_helper.dart';
export 'src/helpers/di_helper.dart';

// Base Classes
export 'src/base/base_use_case.dart';
export 'src/base/base_controller_mixin.dart';


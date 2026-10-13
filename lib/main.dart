import 'app_bootstrap.dart';
import 'core/app_flavor.dart';

/// Default entry — POS (same as [main_pos.dart]).
/// Prefer explicit `-t lib/main_pos.dart` / `main_rapport.dart` with `--flavor`.
Future<void> main() => bootstrapApp(AppFlavor.pos);

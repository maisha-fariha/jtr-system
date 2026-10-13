import 'app_bootstrap.dart';
import 'core/app_flavor.dart';

/// POS floor app entry (`--flavor pos -t lib/main_pos.dart`).
Future<void> main() => bootstrapApp(AppFlavor.pos);

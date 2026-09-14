/// Build flavor: POS floor app vs manager Rapport (JTR Mobile) app.
///
/// Set from entrypoints (`main_pos.dart` / `main_rapport.dart`) before [runApp].
/// Android: different `applicationId` so both APKs install side-by-side
/// (`com.jtrsystem.pos` / `com.jtrsystem.report`).
enum AppFlavor {
  /// Existing waiter / cashier POS (`com.jtrsystem.pos`).
  pos,

  /// Manager Rapport dashboard (`com.jtrsystem.report`).
  rapport,
}

class AppFlavorConfig {
  AppFlavorConfig._();

  static AppFlavor current = AppFlavor.pos;

  static bool get isPos => current == AppFlavor.pos;

  static bool get isRapport => current == AppFlavor.rapport;

  static String get appName =>
      isRapport ? 'JTR Rapport' : 'JTR System';

  /// After login / cold start when authenticated.
  static String get homeRoute =>
      isRapport ? '/jtr-mobile-dashboard' : '/session';

  static void bootstrap(AppFlavor flavor) {
    current = flavor;
  }
}

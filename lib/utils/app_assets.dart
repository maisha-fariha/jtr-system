/// Theme-specific asset paths.
///
/// Place light assets under [light]/ and dark assets under [dark]/.
/// Use [ThemedAssetImage] or [path] to resolve the correct file at runtime.
class AppAssets {
  AppAssets._();

  static const _light = 'assets/images/light';
  static const _dark = 'assets/images/dark';

  static const logoLight = '$_light/logo_text.png';
  static const logoDark = '$_dark/logo_text.png';
}

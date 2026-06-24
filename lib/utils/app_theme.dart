import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFFEE8B78);
  static const Color lightButton = Color(0xFFFDE9E6);
  static const Color darkText = Color(0xFF2D2D2D);
  static const Color background = Colors.white;
  static const Color connectBackground = Color(0xFFF9F9F9);
  static const Color textSecondary = Color(0xFF5A5A5A);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        surface: background,
        onSurface: darkText,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primary),
        titleTextStyle: TextStyle(
          color: primary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      fontFamily: 'Roboto',
    );
  }
}

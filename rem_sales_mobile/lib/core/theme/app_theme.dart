import 'package:flutter/material.dart';

/// Palette ROBUST CODE — reprise des couleurs réellement utilisées dans
/// rem_sales_web (ResellerDashboard.vue et ses 5 onglets) : chrome noir,
/// fond quasi-blanc, accent vert pour les actions de confirmation/succès,
/// et les 3 couleurs de statut de stock (critique/attention/optimal).
class AppColors {
  AppColors._();

  static const black = Color(0xFF000000);
  static const nearBlack = Color(0xFF111111);
  static const canvas = Color(0xFFFFFAFA);
  static const grey = Color(0xFF888888);
  static const border = Color(0xFFE5E5E5);

  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  static const successBg = Color(0xFFF0FDF4);
  static const successText = Color(0xFF166534);
  static const errorBg = Color(0xFFFEF2F2);
  static const errorText = Color(0xFF991B1B);
}

class AppTheme {
  AppTheme._();

  static ThemeData get themeData {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.black,
        primary: AppColors.black,
        surface: AppColors.canvas,
      ),
      scaffoldBackgroundColor: AppColors.canvas,
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: AppColors.grey,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

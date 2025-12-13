import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryNavy = Color(0xFF12355B);
  static const Color accentCrimson = Color(0xFFB31F35);
  static const Color softGold = Color(0xFFD9A441);
  static const Color paleGold = Color(0xFFF3E3C3);
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF22303C);
  static const Color textSecondary = Color(0xFF4F5B67);
  static const Color outline = Color(0xFFE0E4EB);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryNavy,
        primary: AppColors.primaryNavy,
        secondary: AppColors.accentCrimson,
        background: AppColors.background,
        surface: AppColors.surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onBackground: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: 'NotoSans',
        displayColor: AppColors.textPrimary,
        bodyColor: AppColors.textPrimary,
      ).copyWith(
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.paleGold,
        selectedColor: AppColors.softGold,
        labelStyle: const TextStyle(color: AppColors.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryNavy,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryNavy,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryNavy,
          side: const BorderSide(color: AppColors.primaryNavy, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primaryNavy,
        unselectedLabelColor: AppColors.textSecondary,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.accentCrimson, width: 3),
          insets: EdgeInsets.symmetric(horizontal: 24),
        ),
        labelStyle:
            TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.4),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.primaryNavy,
        textColor: AppColors.textPrimary,
        tileColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outline,
        thickness: 1,
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final scheme = base.colorScheme.copyWith(
      primary: const Color(0xFFACC8FF),
      secondary: const Color(0xFFD36A7B),
      surface: const Color(0xFF1E1E24),
      surfaceVariant: const Color(0xFF2A2A33),
      background: const Color(0xFF16161C),
      onBackground: Colors.white,
      onSurface: Colors.white,
      outline: Colors.white24,
    );
    return base.copyWith(
      scaffoldBackgroundColor: scheme.background,
      colorScheme: scheme,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onBackground,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: 'NotoSans',
        bodyColor: scheme.onBackground,
        displayColor: scheme.onBackground,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline,
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surfaceVariant,
        selectedColor: scheme.primary.withOpacity(0.2),
        labelStyle: TextStyle(color: scheme.onBackground),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        ),
      ),
    );
  }
}

LinearGradient get headerGradient => const LinearGradient(
      colors: [
        Color(0xFF0F2B45),
        Color(0xFF184C6F),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

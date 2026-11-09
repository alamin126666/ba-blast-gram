import 'package:flutter/material.dart';

/// BA BLAST GRAM premium theme.
///
/// Telegram blue is the base, lifted with a blue → violet gradient,
/// glass surfaces and soft shadows so the app feels premium instead of
/// a plain clone. Light and dark themes are both first-class.

class BlastColors {
  const BlastColors._();

  // Core brand.
  static const Color primary = Color(0xFF1C93D1); // Telegram blue
  static const Color primaryDeep = Color(0xFF0A6EB5);
  static const Color primarySoft = Color(0xFF37AEE2);
  static const Color violet = Color(0xFF6C5CE7);
  static const Color violetSoft = Color(0xFF8E7CFF);
  static const Color accent = Color(0xFF00C2A8);

  static const LinearGradient brandGradient = LinearGradient(
    colors: <Color>[Color(0xFF229ED9), Color(0xFF6C5CE7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bubbleGradient = LinearGradient(
    colors: <Color>[Color(0xFF2AABEE), Color(0xFF1C93D1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Light theme surfaces.
  static const Color lightBackground = Color(0xFFF2F5F9);
  static const Color lightSurface = Colors.white;
  static const Color lightText = Color(0xFF111B21);
  static const Color lightSubtext = Color(0xFF667781);
  static const Color lightDivider = Color(0xFFE9EDEF);

  // Dark theme surfaces (Telegram dark style).
  static const Color darkBackground = Color(0xFF0E1621);
  static const Color darkSurface = Color(0xFF17212B);
  static const Color darkSurface2 = Color(0xFF1E2C3A);
  static const Color darkText = Color(0xFFF5F5F5);
  static const Color darkSubtext = Color(0xFF7F91A4);
  static const Color darkDivider = Color(0xFF232E3C);

  // Avatar palette (deterministic per chat).
  static const List<Color> avatarPalette = <Color>[
    Color(0xFF1C93D1),
    Color(0xFF6C5CE7),
    Color(0xFF00A884),
    Color(0xFFE76F51),
    Color(0xFFD6336C),
    Color(0xFF2F9E44),
    Color(0xFFF08C00),
    Color(0xFF1971C2),
  ];

  static Color avatarColorFor(String seed) {
    var hash = 0;
    for (var i = 0; i < seed.length; i++) {
      hash = (hash * 31 + seed.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return avatarPalette[hash % avatarPalette.length];
  }
}

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: BlastColors.primary,
      secondary: BlastColors.violet,
      surface: BlastColors.lightSurface,
      error: Color(0xFFD32F2F),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: BlastColors.lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: BlastColors.lightSurface,
        foregroundColor: BlastColors.lightText,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: BlastColors.lightText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: BlastColors.primary,
        foregroundColor: Colors.white,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: BlastColors.primary,
        unselectedLabelColor: BlastColors.lightSubtext,
        indicatorColor: BlastColors.primary,
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: BlastColors.lightSurface,
        selectedItemColor: BlastColors.primary,
        unselectedItemColor: BlastColors.lightSubtext,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0F2F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: BlastColors.primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BlastColors.primary
              : const Color(0xFFCBD5E1),
        ),
      ),
    );
  }

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: BlastColors.primarySoft,
      secondary: BlastColors.violetSoft,
      surface: BlastColors.darkSurface,
      error: Color(0xFFEF5350),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: BlastColors.darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: BlastColors.darkSurface,
        foregroundColor: BlastColors.darkText,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: BlastColors.darkText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: BlastColors.primary,
        foregroundColor: Colors.white,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: BlastColors.primarySoft,
        unselectedLabelColor: BlastColors.darkSubtext,
        indicatorColor: BlastColors.primarySoft,
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: BlastColors.darkSurface,
        selectedItemColor: BlastColors.primarySoft,
        unselectedItemColor: BlastColors.darkSubtext,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BlastColors.darkSurface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: BlastColors.primarySoft,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BlastColors.primary
              : const Color(0xFF475569),
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

/// Karyad brand palette (design canvas «کاریاد — لوگو و رنگ برند»).
abstract final class BrandColors {
  static const teal = Color(0xFF0E6E6D);
  static const tealDark = Color(0xFF0A5251);
  static const tealLight = Color(0xFFE3F1F0);
  static const tealOnDark = Color(0xFF5FC4C0);
  static const coral = Color(0xFFFF7A59);
  static const coralText = Color(0xFFB8452A);
  static const ink = Color(0xFF12201F);
  static const muted = Color(0xFF4A5A59);
  static const background = Color(0xFFF6F9F9);
  static const border = Color(0xFFDCE6E5);
}

abstract final class AppTheme {
  static const fontFamily = 'Vazirmatn';

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: BrandColors.teal,
      primary: BrandColors.teal,
      onPrimary: Colors.white,
      secondary: BrandColors.coral,
      error: BrandColors.coralText,
      surface: Colors.white,
      onSurface: BrandColors.ink,
    );
    return _base(scheme, BrandColors.background);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: BrandColors.teal,
      brightness: Brightness.dark,
      primary: BrandColors.tealOnDark,
      secondary: BrandColors.coral,
    );
    return _base(scheme, BrandColors.ink);
  }

  static ThemeData _base(ColorScheme scheme, Color background) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: background,
    );
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

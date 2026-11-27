import 'package:material_ui/material_ui.dart';

/// Karyad brand palette (design canvas «طرح نهایی · بنفش»).
abstract final class BrandColors {
  static const violet = Color(0xFF4B2E83);
  static const violetDark = Color(0xFF361F63);
  static const violetLight = Color(0xFFEEE8F8);
  static const violetBorder = Color(0xFFE2DCEE);
  static const violetDivider = Color(0xFFF0ECF7);
  static const background = Color(0xFFF6F4FA);
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF544C66);
  static const amber = Color(0xFFF2B84B);
  static const amberBg = Color(0xFFFEF4E2);
  static const amberText = Color(0xFF8A4F06);
  static const danger = Color(0xFFB42318);
  static const dangerBg = Color(0xFFFDECEA);
}

abstract final class AppTheme {
  static const fontFamily = 'Vazirmatn';

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: BrandColors.violet,
          primary: BrandColors.violet,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: BrandColors.ink,
          error: BrandColors.danger,
        ).copyWith(
          primaryContainer: BrandColors.violetLight,
          onPrimaryContainer: BrandColors.violetDark,
          outlineVariant: BrandColors.violetBorder,
          onSurfaceVariant: BrandColors.muted,
          surfaceContainerLowest: Colors.white,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: BrandColors.background,
    );
    final text = base.textTheme.apply(
      bodyColor: BrandColors.ink,
      displayColor: BrandColors.ink,
    );

    return base.copyWith(
      textTheme: text.copyWith(
        bodyLarge: text.bodyLarge?.copyWith(fontSize: 16, height: 1.7),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 15, height: 1.7),
        bodySmall: text.bodySmall?.copyWith(fontSize: 13, height: 1.6),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: BrandColors.background,
        foregroundColor: BrandColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w800,
          fontSize: 22,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: BrandColors.violetBorder),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 54),
          backgroundColor: BrandColors.violet,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 50),
          foregroundColor: BrandColors.violet,
          side: const BorderSide(color: BrandColors.violet, width: 1.5),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BrandColors.violet,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: BrandColors.violetBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: BrandColors.violet, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: BrandColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: BrandColors.danger, width: 1.5),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: BrandColors.violetLight,
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: BrandColors.violetDark,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: BrandColors.violetLight,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w400,
            color: states.contains(WidgetState.selected)
                ? BrandColors.violet
                : BrandColors.muted,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: BrandColors.violetDivider,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

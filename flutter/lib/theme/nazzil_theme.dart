import 'package:flutter/material.dart';

/// A colour theme: [primary] carries buttons and highlights, [accent] the
/// secondary actions, and every tinted surface is mixed from them.
class NazzilPalette {
  const NazzilPalette(this.id, this.primary, this.deep, this.accent);
  final String id;
  final Color primary;
  final Color deep;
  final Color accent;

  static const rose = NazzilPalette('rose', Color(0xFFFF4D8D), Color(0xFFE0186A), Color(0xFFB8A4FF));
  static const ocean = NazzilPalette('ocean', Color(0xFF2F7BFF), Color(0xFF1659D6), Color(0xFF7DE3D4));
  static const emerald = NazzilPalette('emerald', Color(0xFF12B886), Color(0xFF0B8F67), Color(0xFFC3E86B));
  static const sunset = NazzilPalette('sunset', Color(0xFFFF7139), Color(0xFFE2521A), Color(0xFFFFC05C));
  static const grape = NazzilPalette('grape', Color(0xFF8B5CF6), Color(0xFF6D3BE0), Color(0xFFFF9EDB));
  static const all = [rose, ocean, emerald, sunset, grape];

  static NazzilPalette byId(String id) => all.firstWhere((p) => p.id == id, orElse: () => rose);

  Color tint(Color base, double amount) => Color.alphaBlend(primary.withValues(alpha: amount), base);
  Color accentTint(Color base, double amount) => Color.alphaBlend(accent.withValues(alpha: amount), base);
}

class NazzilColors {
  static NazzilPalette palette = NazzilPalette.rose;

  static Color get rose => palette.primary;
  static Color get roseDeep => palette.deep;
  static Color get lilac => palette.accent;
  static Color get paper => palette.tint(const Color(0xFFF6F5F6), 0.05);
  static const cream = Color(0xFFF6F0EA);
  static const ink = Color(0xFF08060C);
  static const ink2 = Color(0xFF161018);
  static const mint = Color(0xFF3DDC97);
}

class NazzilTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final p = NazzilColors.palette;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: NazzilColors.rose,
      onPrimary: Colors.white,
      primaryContainer: dark ? p.tint(NazzilColors.ink, 0.22) : p.tint(Colors.white, 0.22),
      onPrimaryContainer: dark ? NazzilColors.cream : p.tint(NazzilColors.ink, 0.22),
      secondary: NazzilColors.lilac,
      onSecondary: NazzilColors.ink,
      secondaryContainer: dark ? p.accentTint(NazzilColors.ink, 0.18) : p.accentTint(Colors.white, 0.3),
      onSecondaryContainer: dark ? NazzilColors.cream : p.accentTint(NazzilColors.ink, 0.18),
      tertiary: NazzilColors.mint,
      onTertiary: NazzilColors.ink,
      error: const Color(0xFFE23D4A),
      onError: Colors.white,
      surface: dark ? NazzilColors.ink : NazzilColors.paper,
      onSurface: dark ? NazzilColors.cream : const Color(0xFF1A1320),
      onSurfaceVariant: dark ? const Color(0xFFB5A8B4) : const Color(0xFF7A6B76),
      outline: dark ? const Color(0x33FFFFFF) : const Color(0x221A1320),
      outlineVariant: dark ? const Color(0x22FFFFFF) : const Color(0x141A1320),
      surfaceContainerLowest: dark ? const Color(0xFF05040A) : Colors.white,
      surfaceContainerLow: dark ? NazzilColors.ink2 : Colors.white,
      surfaceContainer: dark ? const Color(0xFF1C1522) : p.tint(const Color(0xFFEBE8EB), 0.05),
      surfaceContainerHigh: dark ? const Color(0xFF241C2A) : p.tint(const Color(0xFFE2DFE2), 0.06),
      surfaceContainerHighest: dark ? const Color(0xFF2C2334) : p.tint(const Color(0xFFD9D6D9), 0.07),
    );

    TextStyle outfit({
      double size = 16,
      FontWeight weight = FontWeight.w500,
      double height = 1.25,
      Color? color,
    }) {
      return TextStyle(
        fontFamily: 'Outfit',
        fontFamilyFallback: const ['NotoNaskhArabic'],
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: color ?? scheme.onSurface,
        fontVariations: [FontVariation('wght', weight.value.toDouble())],
      );
    }

    TextStyle arabic({
      double size = 16,
      FontWeight weight = FontWeight.w600,
      double height = 1.45,
      Color? color,
    }) {
      return TextStyle(
        fontFamily: 'NotoNaskhArabic',
        fontFamilyFallback: const ['Outfit'],
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: color ?? scheme.onSurface,
      );
    }

    final text = TextTheme(
      displaySmall: outfit(size: 44, weight: FontWeight.w800, height: 0.95),
      headlineMedium: outfit(size: 28, weight: FontWeight.w800, height: 1.1),
      titleLarge: outfit(size: 22, weight: FontWeight.w700),
      titleMedium: outfit(size: 17, weight: FontWeight.w600),
      bodyLarge: arabic(size: 17, height: 1.55),
      bodyMedium: arabic(size: 15, height: 1.5),
      bodySmall: outfit(size: 13, color: scheme.onSurfaceVariant),
      labelLarge: outfit(size: 15, weight: FontWeight.w700),
      labelMedium: outfit(size: 12, weight: FontWeight.w600, color: scheme.onSurfaceVariant),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: text.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: NazzilColors.rose, width: 1.4),
        ),
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NazzilColors.rose,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          textStyle: text.labelLarge,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow.withValues(alpha: 0.82),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.7)),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
      ),
    );
  }
}

TextStyle displayStyle(BuildContext context, {double size = 40}) {
  final rtl = Directionality.of(context) == TextDirection.rtl;
  return TextStyle(
    fontFamily: rtl ? 'NotoNaskhArabic' : 'Outfit',
    fontFamilyFallback: const ['Outfit', 'NotoNaskhArabic'],
    fontSize: size,
    fontWeight: FontWeight.w800,
    height: rtl ? 1.25 : 0.95,
    letterSpacing: rtl ? 0 : -1.2,
    color: Theme.of(context).colorScheme.onSurface,
  );
}

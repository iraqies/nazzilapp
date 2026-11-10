import 'package:flutter/material.dart';

/// One brand colour: [fill] sits under ink text, while [onDark] and [onLight]
/// are the same hue tuned to pass 4.5:1 as text on each theme's surfaces.
class NazzilPalette {
  const NazzilPalette(this.id, this.fill, this.onDark, this.onLight);
  final String id;
  final Color fill;
  final Color onDark;
  final Color onLight;

  static const rose = NazzilPalette('rose', Color(0xFFFF4D8D), Color(0xFFFF4D8D), Color(0xFFCF004A));
  static const ocean = NazzilPalette('ocean', Color(0xFF2F7BFF), Color(0xFF4388FF), Color(0xFF0059F3));
  static const emerald = NazzilPalette('emerald', Color(0xFF12B886), Color(0xFF12B886), Color(0xFF0B7555));
  static const sunset = NazzilPalette('sunset', Color(0xFFFF7139), Color(0xFFFF7139), Color(0xFFC03600));
  static const grape = NazzilPalette('grape', Color(0xFF8B5CF6), Color(0xFF9A72F7), Color(0xFF753DF4));
  static const all = [rose, ocean, emerald, sunset, grape];

  static NazzilPalette byId(String id) => all.firstWhere((p) => p.id == id, orElse: () => rose);
}

abstract final class NazzilColors {
  static const ink = Color(0xFF0B0B0C);
  static const paper = Color(0xFFF5F3F0);

  /// Scrim behind text that sits on a photo: white on it stays above 4.5:1
  /// even over a white image.
  static const photoScrim = Color(0xB8000000);
}

/// Pill is kept for the main button alone, so it reads as the one thing to press.
abstract final class NazzilRadius {
  static const small = 6.0;
  static const control = 10.0;
  static const card = 16.0;
}

/// Every animation asks here first, so the system reduce-motion setting
/// switches all of them off in one place.
abstract final class NazzilMotion {
  static const quick = Duration(milliseconds: 180);

  static bool reduced(BuildContext context) => MediaQuery.disableAnimationsOf(context);

  static Duration of(BuildContext context, [Duration duration = quick]) =>
      reduced(context) ? Duration.zero : duration;

  static AnimationStyle? style(BuildContext context) => reduced(context) ? AnimationStyle.noAnimation : null;

  static Route<T> route<T>(BuildContext context, WidgetBuilder builder) {
    if (!reduced(context)) return MaterialPageRoute<T>(builder: builder);
    return PageRouteBuilder<T>(
      pageBuilder: (context, _, _) => builder(context),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }
}

class NazzilTheme {
  static ThemeData light(NazzilPalette palette, {required bool arabic}) =>
      _build(Brightness.light, palette, arabic: arabic);
  static ThemeData dark(NazzilPalette palette, {required bool arabic}) =>
      _build(Brightness.dark, palette, arabic: arabic);

  static ThemeData _build(Brightness brightness, NazzilPalette palette, {required bool arabic}) {
    final dark = brightness == Brightness.dark;
    final text = dark ? const Color(0xFFF4F1EC) : const Color(0xFF141215);
    final muted = dark ? const Color(0xFFA9A5A0) : const Color(0xFF625D58);
    final page = dark ? NazzilColors.ink : NazzilColors.paper;
    final surface = dark ? const Color(0xFF161618) : Colors.white;
    final raised = dark ? const Color(0xFF222225) : const Color(0xFFECE9E4);
    final tone = dark ? palette.onDark : palette.onLight;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: tone,
      onPrimary: dark ? NazzilColors.ink : Colors.white,
      primaryContainer: palette.fill,
      onPrimaryContainer: NazzilColors.ink,
      secondary: tone,
      onSecondary: dark ? NazzilColors.ink : Colors.white,
      secondaryContainer: raised,
      onSecondaryContainer: text,
      tertiary: tone,
      onTertiary: dark ? NazzilColors.ink : Colors.white,
      error: dark ? const Color(0xFFFF7A85) : const Color(0xFFB3202C),
      onError: dark ? NazzilColors.ink : Colors.white,
      surface: page,
      onSurface: text,
      onSurfaceVariant: muted,
      // Control edges need 3:1 against the surface next to them.
      outline: dark ? const Color(0xFF737379) : const Color(0xFF85807B),
      outlineVariant: dark ? const Color(0xFF2C2C30) : const Color(0xFFDDD9D3),
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: page,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: raised,
      surfaceContainerHighest: raised,
      inverseSurface: text,
      onInverseSurface: page,
    );

    TextStyle style({
      required double size,
      FontWeight weight = FontWeight.w400,
      double height = 1.3,
      Color? color,
      double spacing = 0,
    }) {
      if (arabic) {
        final w = weight.value.clamp(400, 700);
        return TextStyle(
          fontFamily: 'NotoNaskhArabic',
          fontFamilyFallback: const ['Outfit'],
          fontSize: size,
          fontWeight: FontWeight.values[(w ~/ 100) - 1],
          fontVariations: [FontVariation('wght', w.toDouble())],
          height: height + 0.2,
          color: color ?? text,
        );
      }
      return TextStyle(
        fontFamily: 'Outfit',
        fontFamilyFallback: const ['NotoNaskhArabic'],
        fontSize: size,
        fontWeight: weight,
        fontVariations: [FontVariation('wght', weight.value.toDouble())],
        height: height,
        letterSpacing: spacing,
        color: color ?? text,
      );
    }

    final type = TextTheme(
      displaySmall: style(size: arabic ? 34 : 40, weight: FontWeight.w800, height: 1, spacing: -1),
      headlineMedium: style(size: 26, weight: FontWeight.w800, height: 1.12, spacing: -0.4),
      titleLarge: style(size: 20, weight: FontWeight.w700, height: 1.2),
      titleMedium: style(size: 16, weight: FontWeight.w600, height: 1.25),
      bodyLarge: style(size: 16, height: 1.45),
      bodyMedium: style(size: 15, height: 1.45),
      bodySmall: style(size: 13, weight: FontWeight.w500, color: muted),
      labelLarge: style(size: 15, weight: FontWeight.w700, height: 1.2),
      labelMedium: style(size: 13, weight: FontWeight.w600, height: 1.2, color: muted),
    );

    BorderSide? focusRing(Set<WidgetState> states) => states.contains(WidgetState.focused)
        ? BorderSide(color: text, width: 2, strokeAlign: BorderSide.strokeAlignOutside)
        : null;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: type,
      scaffoldBackgroundColor: page,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: page,
        foregroundColor: text,
        titleTextStyle: type.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: InputBorder.none,
        hintStyle: type.bodyMedium?.copyWith(color: muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? raised : palette.fill,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? muted : NazzilColors.ink,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? muted : NazzilColors.ink,
          ),
          overlayColor: WidgetStatePropertyAll(NazzilColors.ink.withValues(alpha: 0.12)),
          elevation: const WidgetStatePropertyAll(0),
          minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 22)),
          shape: WidgetStateProperty.resolveWith(
            (states) => StadiumBorder(side: focusRing(states) ?? BorderSide.none),
          ),
          textStyle: WidgetStatePropertyAll(type.labelLarge),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? muted : tone,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? muted : tone,
          ),
          minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
          shape: WidgetStateProperty.resolveWith(
            (states) => RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(NazzilRadius.control),
              side: focusRing(states) ?? BorderSide.none,
            ),
          ),
          textStyle: WidgetStatePropertyAll(type.labelLarge),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(text),
          minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
          shape: WidgetStateProperty.resolveWith(
            (states) => RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(NazzilRadius.control),
              side: focusRing(states) ?? BorderSide.none,
            ),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: type.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NazzilRadius.control)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        titleTextStyle: type.titleLarge,
        contentTextStyle: type.bodyMedium?.copyWith(color: muted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NazzilRadius.card)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        elevation: 0,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(NazzilRadius.card)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: text,
        textColor: text,
        titleTextStyle: type.titleMedium,
        subtitleTextStyle: type.bodySmall,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NazzilRadius.control)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tone,
        linearTrackColor: scheme.outlineVariant,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }
}

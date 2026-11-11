import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One of the five colours a user can pick. It fills the button that does the
/// next step and draws the front line of an arriving picture, and nothing else.
class NazzilPalette {
  const NazzilPalette(this.id, this.fill);
  final String id;
  final Color fill;

  static const rose = NazzilPalette('rose', Color(0xFFFF4D8D));
  static const ocean = NazzilPalette('ocean', Color(0xFF2F7BFF));
  static const emerald = NazzilPalette('emerald', Color(0xFF12B886));
  static const sunset = NazzilPalette('sunset', Color(0xFFFF7139));
  static const grape = NazzilPalette('grape', Color(0xFF8B5CF6));
  static const all = [rose, ocean, emerald, sunset, grape];

  static NazzilPalette byId(String id) => all.firstWhere((p) => p.id == id, orElse: () => rose);
}

abstract final class NazzilColors {
  /// Text on the picked colour. It passes 4.5:1 on all five; white fails on all five.
  static const ink = Color(0xFF0B0B0C);

  /// Scrim behind a tag on a picture: white on it stays above 4.5:1 even over a white photo.
  static const photoScrim = Color(0xB8000000);
  static const onPhoto = Color(0xFFFFFFFF);

  /// The close button on a poster is the same black disc in both themes.
  static const screen = Color(0xFF000000);
  static const onScreen = Color(0xFFF5F3EE);

  /// A picture that is not on the device: grey, at 42% of its brightness.
  static const unsaved = ColorFilter.matrix(<double>[
    0.0893, 0.3004, 0.0303, 0, 0, //
    0.0893, 0.3004, 0.0303, 0, 0, //
    0.0893, 0.3004, 0.0303, 0, 0, //
    0, 0, 0, 1, 0,
  ]);
}

/// Pictures have square corners; these are for the controls around them.
abstract final class NazzilRadius {
  static const tag = 4.0;
  static const control = 8.0;
  static const sheet = 12.0;
}

/// Every animation asks here first, so the system reduce-motion setting
/// switches all of them off in one place.
abstract final class NazzilMotion {
  static const quick = Duration(milliseconds: 180);

  /// Colour catching up with the download between two progress reports.
  static const arrive = Duration(milliseconds: 250);

  /// The frame taking the shape of its picture.
  static const reshape = Duration(milliseconds: 220);

  /// Colour crossing a picture once, when its download lands.
  static const sweep = Duration(milliseconds: 700);

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
  static const family = 'Archivo';

  /// Archivo holds no Arabic, so Arabic falls through to Changa and Latin keeps one face.
  static const fallback = ['Changa'];

  static ThemeData light(NazzilPalette palette, {required bool arabic}) =>
      _build(Brightness.light, palette, arabic: arabic);
  static ThemeData dark(NazzilPalette palette, {required bool arabic}) =>
      _build(Brightness.dark, palette, arabic: arabic);

  /// Status bar and navigation bar colours for a page of this [brightness].
  /// [onPicture] is for a status bar that lies over a poster and its dark fade.
  static SystemUiOverlayStyle overlay(Brightness brightness, Color page, {bool onPicture = false}) {
    final icons = brightness == Brightness.dark ? Brightness.light : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: onPicture ? Brightness.light : icons,
      statusBarBrightness: onPicture ? Brightness.dark : brightness,
      systemNavigationBarColor: page,
      systemNavigationBarIconBrightness: icons,
      systemNavigationBarDividerColor: page,
    );
  }

  static ThemeData _build(Brightness brightness, NazzilPalette palette, {required bool arabic}) {
    final dark = brightness == Brightness.dark;
    final text = dark ? const Color(0xFFF5F3EE) : const Color(0xFF111111);
    final muted = dark ? const Color(0xFFA8A49C) : const Color(0xFF5F5B54);
    final page = dark ? const Color(0xFF000000) : const Color(0xFFF4F2EE);
    final sheet = dark ? const Color(0xFF161616) : const Color(0xFFFFFFFF);
    final raised = dark ? const Color(0xFF222222) : const Color(0xFFE9E6E0);
    final line = dark ? const Color(0xFF2E2E2E) : const Color(0xFFD5D0C6);
    final edge = dark ? const Color(0xFF777777) : const Color(0xFF807B72);
    final scheme = ColorScheme(
      brightness: brightness,
      // A picked choice is the text colour, lettered in the page colour.
      primary: text,
      onPrimary: page,
      // The picked colour is kept for the button that does the next step.
      primaryContainer: palette.fill,
      onPrimaryContainer: NazzilColors.ink,
      secondary: text,
      onSecondary: page,
      secondaryContainer: raised,
      onSecondaryContainer: text,
      tertiary: text,
      onTertiary: page,
      error: dark ? const Color(0xFFFF7A85) : const Color(0xFFB3202C),
      onError: dark ? NazzilColors.ink : Colors.white,
      surface: page,
      onSurface: text,
      onSurfaceVariant: muted,
      // Control edges need 3:1 against the surface next to them.
      outline: edge,
      outlineVariant: line,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: page,
      surfaceContainerLow: sheet,
      surfaceContainer: sheet,
      surfaceContainerHigh: raised,
      surfaceContainerHighest: raised,
      inverseSurface: text,
      onInverseSurface: page,
    );

    // [width] is Archivo's width axis: 100 is the regular cut, 62 the narrowest.
    // Changa has one width, needs taller lines, and letter spacing would break its joins.
    TextStyle style({
      required double size,
      FontWeight weight = FontWeight.w400,
      double width = 100,
      double height = 1.3,
      Color? color,
      bool latinOnly = false,
    }) {
      return TextStyle(
        fontFamily: family,
        fontFamilyFallback: fallback,
        fontSize: size,
        fontWeight: weight,
        fontVariations: [FontVariation('wght', weight.value.toDouble()), FontVariation('wdth', width)],
        height: arabic && !latinOnly ? height + 0.2 : height,
        letterSpacing: 0,
        color: color ?? text,
      );
    }

    final type = TextTheme(
      // The percentage on a poster: digits only, so it keeps Latin line metrics in Arabic too.
      displayLarge: style(size: 88, weight: FontWeight.w800, width: 62.5, height: 0.86, latinOnly: true)
          .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      displaySmall: style(size: arabic ? 36 : 42, weight: FontWeight.w800, width: 75, height: 1.05),
      headlineMedium: style(size: 30, weight: FontWeight.w800, width: 75, height: 1.06),
      headlineSmall: style(size: 26, weight: FontWeight.w800, width: 75, height: 1.1),
      titleLarge: style(size: 21, weight: FontWeight.w800, width: 87.5, height: 1.2),
      titleMedium: style(size: 17, weight: FontWeight.w800, width: 87.5, height: 1.25),
      titleSmall: style(size: 16, weight: FontWeight.w600, height: 1.25),
      bodyLarge: style(size: 16, height: 1.45),
      bodyMedium: style(size: 15, height: 1.45),
      bodySmall: style(size: 14, height: 1.4, color: muted),
      labelLarge: style(size: 15, weight: FontWeight.w700, height: 1.2),
      labelMedium: style(size: 13.5, weight: FontWeight.w500, height: 1.35, color: muted),
      labelSmall: style(size: 12.5, weight: FontWeight.w600, height: 1.2),
    );

    BorderSide? focusRing(Set<WidgetState> states) => states.contains(WidgetState.focused)
        ? BorderSide(color: text, width: 2, strokeAlign: BorderSide.strokeAlignOutside)
        : null;

    OutlinedBorder control(Set<WidgetState> states) => RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NazzilRadius.control),
          side: focusRing(states) ?? BorderSide.none,
        );

    Color quiet(Set<WidgetState> states) => states.contains(WidgetState.disabled) ? muted : text;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: type,
      scaffoldBackgroundColor: page,
      splashFactory: InkRipple.splashFactory,
      // One size of control on every platform: a computer would otherwise shave 8 off each.
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: page,
        foregroundColor: text,
        titleTextStyle: type.titleLarge,
        systemOverlayStyle: overlay(brightness, page),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: InputBorder.none,
        hintStyle: type.bodyLarge?.copyWith(color: muted),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: text,
        selectionColor: text.withValues(alpha: 0.3),
        selectionHandleColor: text,
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
          iconSize: const WidgetStatePropertyAll(22),
          overlayColor: WidgetStatePropertyAll(NazzilColors.ink.withValues(alpha: 0.12)),
          elevation: const WidgetStatePropertyAll(0),
          minimumSize: const WidgetStatePropertyAll(Size(64, 56)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20)),
          shape: WidgetStateProperty.resolveWith(control),
          textStyle: WidgetStatePropertyAll(
            style(size: 17, weight: FontWeight.w700, height: 1.2),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(quiet),
          iconColor: WidgetStateProperty.resolveWith(quiet),
          iconSize: const WidgetStatePropertyAll(22),
          overlayColor: WidgetStatePropertyAll(text.withValues(alpha: 0.1)),
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
          shape: WidgetStateProperty.resolveWith(control),
          textStyle: WidgetStatePropertyAll(type.labelLarge),
        ),
      ),
      // An action that stands alone as words gets an outline, since no colour marks it as a button.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(quiet),
          iconColor: WidgetStateProperty.resolveWith(quiet),
          iconSize: const WidgetStatePropertyAll(22),
          overlayColor: WidgetStatePropertyAll(text.withValues(alpha: 0.1)),
          minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
          side: WidgetStateProperty.resolveWith(
            (states) => focusRing(states) ?? BorderSide(color: edge, width: 1.5),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(NazzilRadius.control)),
          ),
          textStyle: WidgetStatePropertyAll(type.labelLarge),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? text.withValues(alpha: 0.38) : text,
          ),
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          shape: WidgetStateProperty.resolveWith(control),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: type.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NazzilRadius.control)),
      ),
      // Sheets, dialogs and menus are flat, so a hairline is what parts them from the page.
      dialogTheme: DialogThemeData(
        backgroundColor: sheet,
        elevation: 0,
        titleTextStyle: type.titleLarge,
        contentTextStyle: type.bodyMedium?.copyWith(color: muted),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NazzilRadius.sheet),
          side: BorderSide(color: line),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: sheet,
        modalBackgroundColor: sheet,
        elevation: 0,
        modalElevation: 0,
        dragHandleColor: edge,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(NazzilRadius.sheet)),
          side: BorderSide(color: line),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: sheet,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(type.titleSmall),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NazzilRadius.control),
          side: BorderSide(color: edge),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: text, borderRadius: BorderRadius.circular(NazzilRadius.tag)),
        textStyle: type.labelMedium?.copyWith(color: page),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: text,
        textColor: text,
        titleTextStyle: type.titleSmall,
        subtitleTextStyle: type.bodySmall,
        minTileHeight: 52,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NazzilRadius.control)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: text,
        linearTrackColor: line,
        circularTrackColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: line, space: 1, thickness: 1),
    );
  }
}

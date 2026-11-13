import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class NazzilColors {
  /// The one accent of the interface: Polyfrost's blue. It fills the button that
  /// does the next step, the bar a download fills, and the mark on the logo, and is
  /// kept to those, the sparing way the frost is spent. The owner asked to take after
  /// Polyfrost on 2026-11-13.
  static const tint = Color(0xFF1F65D6);

  /// Text on the tint. White clears 4.5:1 on this blue, so the filled button carries
  /// white letters, the way Apple's own buttons do.
  static const onTint = Color(0xFFFFFFFF);

  /// Dark text for the odd light fill, such as the warning red, where white would not clear 4.5:1.
  static const ink = Color(0xFF0B0B0C);

  /// Scrim behind a tag on a picture: white on it stays above 4.5:1 even over a white photo.
  static const photoScrim = Color(0xB8000000);
  static const onPhoto = Color(0xFFFFFFFF);

  /// The close button on a poster is the same black disc in both themes.
  static const screen = Color(0xFF000000);
  static const onScreen = Color(0xFFF5F5F7);

  /// A picture that is not on the device: grey, at 42% of its brightness.
  static const unsaved = ColorFilter.matrix(<double>[
    0.0893, 0.3004, 0.0303, 0, 0, //
    0.0893, 0.3004, 0.0303, 0, 0, //
    0.0893, 0.3004, 0.0303, 0, 0, //
    0, 0, 0, 1, 0,
  ]);
}

/// iOS rounds its corners, so controls, cells and sheets all carry a radius.
/// The media keeps square, full-bleed edges; these are for the chrome around it.
abstract final class NazzilRadius {
  static const tag = 6.0;
  static const control = 12.0;
  static const card = 18.0;
  static const sheet = 18.0;
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
    if (!reduced(context)) {
      // Cupertino's horizontal slide is the native transition the owner asked for.
      return CupertinoPageRoute<T>(builder: builder);
    }
    return PageRouteBuilder<T>(
      pageBuilder: (context, _, _) => builder(context),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }
}

class NazzilTheme {
  /// The Latin interface is set in Inter, the closest openly licensed match to
  /// Apple's San Francisco: a neutral UI sans with a tall x-height and real
  /// tabular figures. The owner asked for a native-Apple look on 2026-11-13.
  static const sans = 'Inter';

  /// Arabic is set in IBM Plex Sans Arabic, a clean humanist sans that sits at
  /// the Latin size and reads like Apple's SF Arabic beside Inter. The logo keeps
  /// its own Ruqaa lettering, drawn from an outline, so the brand mark is unchanged.
  static const arabicSans = 'IBM Plex Sans Arabic';

  /// What is set strong. Both typefaces carry a semibold at this weight.
  static const strong = FontWeight.w600;

  /// Both typefaces are drawn to sit on the same line at the same point size, so
  /// one text size suits both scripts with no enlargement and no extra lead.
  static const arabicScale = 1.0;
  static const arabicLead = 0.0;

  /// [style] as it is set for Arabic words, or for Latin ones: that script's typeface
  /// first, and its lines. A theme sets its own language, so this is for a run of the
  /// other one: an Arabic title in the English app, a link in the Arabic app.
  static TextStyle inScript(TextStyle style, {required bool arabic}) {
    final first = style.fontFamily;
    final next = style.fontFamilyFallback;
    if (first == null || next == null || next.isEmpty || (first == arabicSans) == arabic) return style;
    final height = style.height;
    return style.copyWith(
      fontFamily: next.first,
      fontFamilyFallback: [first, ...next.skip(1)],
      height: height == null
          ? null
          : arabic
              ? (height + arabicLead) * arabicScale
              : height / arabicScale - arabicLead,
    );
  }

  static ThemeData light({required bool arabic}) => _build(Brightness.light, arabic: arabic);
  static ThemeData dark({required bool arabic}) => _build(Brightness.dark, arabic: arabic);

  /// A translucent fill for the blurred bars (tab bar, nav bar), the one iOS
  /// material. Laid over a backdrop blur it is the system's own chrome.
  static Color barFill(ColorScheme scheme) =>
      scheme.surface.withValues(alpha: scheme.brightness == Brightness.dark ? 0.72 : 0.82);

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

  static ThemeData _build(Brightness brightness, {required bool arabic}) {
    final dark = brightness == Brightness.dark;
    // apple.com's palette: the deep near-black #1D1D1F with raised greys in the
    // dark, the soft #F5F5F7 with white cells in the light.
    final text = dark ? const Color(0xFFFFFFFF) : const Color(0xFF1D1D1F);
    final muted = dark ? const Color(0xFFA1A1A6) : const Color(0xFF6E6E73);
    final page = dark ? const Color(0xFF1D1D1F) : const Color(0xFFF5F5F7);
    final sheet = dark ? const Color(0xFF2C2C2E) : const Color(0xFFFFFFFF);
    final raised = dark ? const Color(0xFF2C2C2E) : const Color(0xFFFFFFFF);
    // Hairlines sit light; control edges carry 3:1 so a bare outline reads.
    final line = dark ? const Color(0xFF38383A) : const Color(0xFFD2D2D7);
    final edge = dark ? const Color(0xFF8A8A8E) : const Color(0xFF6D6D72);
    final scheme = ColorScheme(
      brightness: brightness,
      // A picked choice is the text colour, lettered in the page colour.
      primary: text,
      onPrimary: page,
      // The tint fills the button that does the next step.
      primaryContainer: NazzilColors.tint,
      onPrimaryContainer: NazzilColors.onTint,
      secondary: text,
      onSecondary: page,
      secondaryContainer: raised,
      onSecondaryContainer: text,
      tertiary: text,
      onTertiary: page,
      error: dark ? const Color(0xFFFF6961) : const Color(0xFFD70015),
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

    // One size suits both scripts. Letter spacing stays at zero because it would
    // break the joins of Arabic.
    TextStyle style(
      double size, {
      bool bold = false,
      double height = 1.35,
      Color? color,
      bool digits = false,
    }) {
      final base = TextStyle(
        fontFamily: sans,
        fontFamilyFallback: const [arabicSans],
        fontSize: size,
        fontWeight: bold ? strong : FontWeight.w400,
        height: height,
        leadingDistribution: TextLeadingDistribution.even,
        letterSpacing: 0,
        color: color ?? text,
      );
      return arabic && !digits ? inScript(base, arabic: true) : base;
    }

    // An iOS type ramp: a large title, headline and body, down to the tab label.
    final type = TextTheme(
      // The percentage on a poster: digits only, so it is the same in both languages.
      displayLarge: style(80, bold: true, height: 0.92, digits: true)
          .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      displaySmall: style(34, bold: true, height: 1.1),
      headlineMedium: style(25, bold: true, height: 1.2),
      headlineSmall: style(22, bold: true, height: 1.2),
      titleLarge: style(20, bold: true, height: 1.25),
      titleMedium: style(17, bold: true, height: 1.3),
      titleSmall: style(16, bold: true, height: 1.3),
      bodyLarge: style(17, height: 1.4),
      bodyMedium: style(16, height: 1.4),
      bodySmall: style(15, height: 1.35, color: muted),
      labelLarge: style(17, bold: true, height: 1.2),
      labelMedium: style(13, height: 1.35, color: muted),
      labelSmall: style(11, height: 1.2),
    );

    BorderSide? focusRing(Set<WidgetState> states) => states.contains(WidgetState.focused)
        ? BorderSide(color: text, width: 2, strokeAlign: BorderSide.strokeAlignOutside)
        : null;

    OutlinedBorder control(Set<WidgetState> states) => RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NazzilRadius.control),
          side: focusRing(states) ?? BorderSide.none,
        );

    // apple.com rounds its buttons all the way to a pill.
    OutlinedBorder pill(Set<WidgetState> states) => StadiumBorder(side: focusRing(states) ?? BorderSide.none);

    Color quiet(Set<WidgetState> states) => states.contains(WidgetState.disabled) ? muted : text;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: type,
      scaffoldBackgroundColor: page,
      // iOS answers a tap with a quick dim, not a spreading ripple.
      splashFactory: NoSplash.splashFactory,
      // One size of control on every platform: a computer would otherwise shave 8 off each.
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: page,
        foregroundColor: text,
        centerTitle: true,
        titleTextStyle: type.titleMedium,
        systemOverlayStyle: overlay(brightness, page),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: InputBorder.none,
        hintStyle: type.bodyLarge?.copyWith(color: muted),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: NazzilColors.tint,
        selectionColor: NazzilColors.tint.withValues(alpha: 0.28),
        selectionHandleColor: NazzilColors.tint,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? raised : NazzilColors.tint,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? muted : NazzilColors.onTint,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? muted : NazzilColors.onTint,
          ),
          iconSize: const WidgetStatePropertyAll(21),
          overlayColor: WidgetStatePropertyAll(NazzilColors.onTint.withValues(alpha: 0.16)),
          elevation: const WidgetStatePropertyAll(0),
          minimumSize: const WidgetStatePropertyAll(Size(64, 50)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 24)),
          shape: WidgetStateProperty.resolveWith(pill),
          textStyle: WidgetStatePropertyAll(style(17, bold: true, height: 1.2)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(quiet),
          iconColor: WidgetStateProperty.resolveWith(quiet),
          iconSize: const WidgetStatePropertyAll(21),
          overlayColor: WidgetStatePropertyAll(text.withValues(alpha: 0.08)),
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
          iconSize: const WidgetStatePropertyAll(21),
          overlayColor: WidgetStatePropertyAll(text.withValues(alpha: 0.08)),
          minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
          side: WidgetStateProperty.resolveWith(
            (states) => focusRing(states) ?? BorderSide(color: edge, width: 1.5),
          ),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          textStyle: WidgetStatePropertyAll(type.labelLarge),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? text.withValues(alpha: 0.38) : text,
          ),
          overlayColor: WidgetStatePropertyAll(text.withValues(alpha: 0.08)),
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
      // Dialogs are the rounded, centred iOS kind; a hairline parts a sheet from the page.
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

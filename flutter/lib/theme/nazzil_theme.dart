import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class NazzilColors {
  /// The one accent of the interface: Finery's sapphire. It fills the button that
  /// does the next step and the bar a download fills, and marks the logo. The owner
  /// asked to take after Finery (finery.theiraqieslove.workers.dev) on 2026-11-13.
  static const tint = Color(0xFF0071E3);

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

/// Finery's corners: tiles round wide, controls and fields at 14, badges all the way.
abstract final class NazzilRadius {
  static const tag = 6.0;
  static const control = 14.0;
  static const picture = 18.0;
  static const card = 28.0;
  static const sheet = 26.0;
  static const pill = 999.0;
}

abstract final class NazzilLayout {
  /// From this width up a toolbar runs across the window, over one page that
  /// holds the post on show and the library.
  static const wide = 720.0;

  /// A phone on its side can be as wide, but is too short for a toolbar over the page.
  static const tall = 480.0;

  static bool isWide(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.size.width - media.padding.horizontal >= wide && media.size.height >= tall;
  }
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

  /// Finery's titles and eyebrows. Both typefaces carry a bold.
  static const bold = FontWeight.w700;

  /// Finery's headlines. Inter carries an extra bold; IBM Plex Sans Arabic stops at
  /// bold, which is what an Arabic headline is drawn in.
  static const heavy = FontWeight.w800;

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
      // Spacing between letters breaks the joins of Arabic.
      letterSpacing: arabic ? 0 : style.letterSpacing,
    );
  }

  static ThemeData light({required bool arabic}) => _build(Brightness.light, arabic: arabic);
  static ThemeData dark({required bool arabic}) => _build(Brightness.dark, arabic: arabic);

  /// Words in the accent, such as an eyebrow or a link. The fill blue itself falls
  /// short of 4.5:1 for small words on the page, so they take Apple's link blues.
  static Color link(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFF2997FF) : const Color(0xFF0066CC);

  /// Finery's tile shadow: a hairline of shade under the edge and a wide soft fall
  /// below. On a black page a shadow cannot show, so a dark tile stands on its grey.
  static List<BoxShadow> tileShadow(Brightness brightness) => brightness == Brightness.dark
      ? const []
      : const [
          BoxShadow(color: Color(0x0A000000), offset: Offset(0, 1), blurRadius: 1),
          BoxShadow(color: Color(0x0F000000), offset: Offset(0, 12), blurRadius: 34),
        ];

  /// The glow under the button that does the next step, in its own blue.
  static const glow = [BoxShadow(color: Color(0x3D0071E3), offset: Offset(0, 8), blurRadius: 16)];

  /// The shadow a thing on show casts on its stand.
  static const pedestal = [BoxShadow(color: Color(0x290F1626), offset: Offset(0, 18), blurRadius: 23)];

  /// The faint light from above on a showcase tile.
  static LinearGradient showcase(Brightness brightness) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: brightness == Brightness.dark
            ? const [Color(0xFF222327), Color(0xFF141519)]
            : const [Color(0xFFFBFBFD), Color(0xFFEAEEF5)],
      );

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
    // Finery's palette: the soft #F5F5F7 page with white tiles and #1D1D1F ink in
    // the light; a black page with iOS's grouped greys in the dark. A field or a
    // track inside a tile is set one step off the tile.
    final text = dark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);
    final muted = dark ? const Color(0xFFA1A1A6) : const Color(0xFF6E6E73);
    final page = dark ? const Color(0xFF000000) : const Color(0xFFF5F5F7);
    final sheet = dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
    final raised = dark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F3F7);
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

    // One size suits both scripts. Finery draws its Latin headlines tight, so
    // [tracking] is in ems, as it sets them; Arabic is never spaced (see inScript).
    TextStyle style(
      double size, {
      FontWeight weight = FontWeight.w400,
      double height = 1.35,
      double tracking = 0,
      Color? color,
      bool digits = false,
    }) {
      final base = TextStyle(
        fontFamily: sans,
        fontFamilyFallback: const [arabicSans],
        fontSize: size,
        fontWeight: weight,
        height: height,
        leadingDistribution: TextLeadingDistribution.even,
        letterSpacing: tracking * size,
        color: color ?? text,
      );
      return arabic && !digits ? inScript(base, arabic: true) : base;
    }

    // Finery's ramp: heavy, tight headlines over plain reading sizes.
    final type = TextTheme(
      // The percentage on a poster: digits only, so it is the same in both languages.
      displayLarge: style(80, weight: strong, height: 0.92, digits: true)
          .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      displaySmall: style(34, weight: heavy, height: 1.08, tracking: -0.035),
      headlineMedium: style(24, weight: heavy, height: 1.16, tracking: -0.025),
      headlineSmall: style(22, weight: heavy, height: 1.2, tracking: -0.02),
      titleLarge: style(20, weight: bold, height: 1.25, tracking: -0.02),
      titleMedium: style(17, weight: bold, height: 1.3, tracking: -0.01),
      titleSmall: style(16, weight: strong, height: 1.3),
      bodyLarge: style(17, height: 1.4, tracking: -0.01),
      bodyMedium: style(16, height: 1.4),
      bodySmall: style(15, height: 1.35, color: muted),
      labelLarge: style(16, weight: strong, height: 1.2, tracking: -0.01),
      labelMedium: style(13, height: 1.35, color: muted),
      labelSmall: style(12, weight: strong, height: 1.2),
    );

    BorderSide? focusRing(Set<WidgetState> states) => states.contains(WidgetState.focused)
        ? BorderSide(color: text, width: 2, strokeAlign: BorderSide.strokeAlignOutside)
        : null;

    OutlinedBorder control(Set<WidgetState> states) => RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NazzilRadius.control),
          side: focusRing(states) ?? BorderSide.none,
        );

    final link = NazzilTheme.link(brightness);
    // A second action is the accent's words on a wash of it, as iOS tints a bordered button.
    final wash = dark ? const Color(0xFF1A2A3D) : const Color(0xFFE8F0FB);

    Color linked(Set<WidgetState> states) => states.contains(WidgetState.disabled) ? muted : link;

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
          minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 22)),
          shape: WidgetStateProperty.resolveWith(control),
          textStyle: WidgetStatePropertyAll(type.labelLarge),
        ),
      ),
      // Words that act are in the accent, as Apple sets a link.
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(linked),
          iconColor: WidgetStateProperty.resolveWith(linked),
          iconSize: const WidgetStatePropertyAll(21),
          overlayColor: WidgetStatePropertyAll(link.withValues(alpha: 0.1)),
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
          shape: WidgetStateProperty.resolveWith(control),
          textStyle: WidgetStatePropertyAll(type.labelLarge),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? raised : wash,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(linked),
          iconColor: WidgetStateProperty.resolveWith(linked),
          iconSize: const WidgetStatePropertyAll(21),
          overlayColor: WidgetStatePropertyAll(link.withValues(alpha: 0.1)),
          minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18)),
          side: WidgetStateProperty.resolveWith((states) => focusRing(states) ?? BorderSide.none),
          shape: WidgetStateProperty.resolveWith(control),
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
      // Dialogs and sheets are tiles of their own, rounded wide like the rest.
      dialogTheme: DialogThemeData(
        backgroundColor: sheet,
        elevation: 0,
        titleTextStyle: type.titleLarge,
        contentTextStyle: type.bodyMedium?.copyWith(color: muted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NazzilRadius.sheet)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: sheet,
        modalBackgroundColor: sheet,
        elevation: 0,
        modalElevation: 0,
        dragHandleColor: edge,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(NazzilRadius.sheet)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: sheet,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(type.titleSmall),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NazzilRadius.control),
          side: BorderSide(color: line),
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

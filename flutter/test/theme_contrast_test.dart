import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nazzil/theme/nazzil_theme.dart';

import 'support/typefaces.dart';

double ratio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final palette in NazzilPalette.all) {
    for (final brightness in Brightness.values) {
      final theme = brightness == Brightness.dark
          ? NazzilTheme.dark(palette, arabic: false)
          : NazzilTheme.light(palette, arabic: false);
      final scheme = theme.colorScheme;
      final surfaces = {
        'page': scheme.surface,
        'sheet': scheme.surfaceContainerLow,
        'raised': scheme.surfaceContainerHigh,
      };

      test('${palette.id} ${brightness.name}: text passes 4.5:1 on every surface', () {
        final inks = {
          'text': scheme.onSurface,
          'muted': scheme.onSurfaceVariant,
          'error': scheme.error,
        };
        for (final surface in surfaces.entries) {
          for (final ink in inks.entries) {
            expect(
              ratio(ink.value, surface.value),
              greaterThanOrEqualTo(4.5),
              reason: '${ink.key} on ${surface.key}',
            );
          }
        }
        // The button that does the next step is told by its words, so the
        // words carry the contrast: ink on the picked colour.
        expect(scheme.primaryContainer, palette.fill);
        expect(scheme.onPrimaryContainer, NazzilColors.ink);
        expect(ratio(scheme.onPrimaryContainer, scheme.primaryContainer), greaterThanOrEqualTo(4.5));
        // A picked choice is filled with the text colour and written in the page colour.
        expect(ratio(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(4.5));
        expect(ratio(scheme.onInverseSurface, scheme.inverseSurface), greaterThanOrEqualTo(4.5));
      });

      test('${palette.id} ${brightness.name}: control edges and the picked choice pass 3:1', () {
        for (final surface in surfaces.entries) {
          expect(ratio(scheme.outline, surface.value), greaterThanOrEqualTo(3), reason: 'edge on ${surface.key}');
          expect(ratio(scheme.primary, surface.value), greaterThanOrEqualTo(3), reason: 'picked on ${surface.key}');
        }
      });

      test('${palette.id} ${brightness.name}: the interface itself has no colour', () {
        for (final colour in [
          scheme.surface,
          scheme.surfaceContainerLow,
          scheme.surfaceContainerHigh,
          scheme.onSurface,
          scheme.onSurfaceVariant,
          scheme.outline,
          scheme.outlineVariant,
          scheme.primary,
          scheme.onPrimary,
        ]) {
          // Warm greys at most: no channel strays far from the others.
          final channels = [colour.r, colour.g, colour.b];
          expect(channels.reduce(math.max) - channels.reduce(math.min), lessThan(0.08), reason: '$colour');
        }
      });
    }
  }

  test('white text on the photo scrim passes 4.5:1 even over a white photo', () {
    final worst = Color.alphaBlend(NazzilColors.photoScrim, Colors.white);
    expect(ratio(NazzilColors.onPhoto, worst), greaterThanOrEqualTo(4.5));
  });

  test('the close button on a poster passes 4.5:1 on its own disc', () {
    expect(ratio(NazzilColors.onScreen, NazzilColors.screen), greaterThanOrEqualTo(4.5));
  });

  List<TextStyle> stylesOf(TextTheme type) => [
        type.displayLarge!,
        type.displaySmall!,
        type.headlineMedium!,
        type.headlineSmall!,
        type.titleLarge!,
        type.titleMedium!,
        type.titleSmall!,
        type.bodyLarge!,
        type.bodyMedium!,
        type.bodySmall!,
        type.labelLarge!,
        type.labelMedium!,
        type.labelSmall!,
      ];

  test('english is set in the serif and arabic in the hand of the logo, each behind the other', () {
    for (final arabic in [false, true]) {
      final type = NazzilTheme.dark(NazzilPalette.rose, arabic: arabic).textTheme;
      for (final style in stylesOf(type)) {
        final latinFirst = !arabic || style == type.displayLarge;
        final serif = style.fontSize! >= 21 ? NazzilTheme.serifDisplay : NazzilTheme.serif;
        // A word in the other script falls through to the other typeface, so neither is ever
        // left to whatever the phone has.
        expect(style.fontFamily, latinFirst ? serif : NazzilTheme.ruqaa);
        expect(style.fontFamilyFallback, [latinFirst ? NazzilTheme.ruqaa : serif]);
        expect(style.fontWeight, anyOf(FontWeight.w400, NazzilTheme.strong));
        // Spacing between letters breaks the joins of Arabic.
        expect(style.letterSpacing, 0);
        expect(style.wordSpacing, isNull, reason: 'each typeface spaces its own words');
      }
    }
  });

  test('the app ships the typefaces it sets, in the weights it sets them', () {
    final shipped = shippedTypefaces();
    expect(shipped.keys, unorderedEquals([NazzilTheme.serif, NazzilTheme.serifDisplay, NazzilTheme.ruqaa]));
    Set<int> weights(String family) => {for (final file in shipped[family]!) typefaceFacts(file).weight};
    // A weight that is not shipped would be faked by the screen, by smearing the letters.
    expect(weights(NazzilTheme.serif), {400, NazzilTheme.strong.value});
    expect(weights(NazzilTheme.serifDisplay), {NazzilTheme.strong.value});
    // Ruqaa has a regular and a bold, and the bold answers for what is set strong.
    expect(weights(NazzilTheme.ruqaa), {400, 700});
    expect(NazzilTheme.strong.value, greaterThan(500), reason: 'at 500 or less a screen picks the regular');
  });

  test('the two typefaces stand on one line: the same size of letter, the same middle', () {
    final shipped = shippedTypefaces();
    final latin = [...shipped[NazzilTheme.serif]!, ...shipped[NazzilTheme.serifDisplay]!].map(typefaceFacts);
    final arabic = shipped[NazzilTheme.ruqaa]!.map(typefaceFacts);
    double middle(({int weight, int body, int above, int below}) f) => (f.above - f.below) / 2 / f.body;
    for (final a in arabic) {
      // Ruqaa is drawn on a body of 1000. The app's copy says a smaller one, which is what
      // enlarges its letters, and the theme gives Arabic lines as much more room.
      expect(1000 / a.body, closeTo(NazzilTheme.arabicScale, 1e-9));
      for (final l in latin) {
        // A line is centred on the middle each typeface claims. Where they agree, a line
        // holding both scripts is no taller than a line holding one.
        expect(middle(a), closeTo(middle(l), 0.001));
      }
    }
  });

  test('one text size suits both scripts, and arabic stands on taller lines', () {
    final latin = NazzilTheme.dark(NazzilPalette.rose, arabic: false).textTheme;
    final arabic = NazzilTheme.dark(NazzilPalette.rose, arabic: true).textTheme;
    for (final (a, l) in [
      (arabic.displaySmall!, latin.displaySmall!),
      (arabic.titleMedium!, latin.titleMedium!),
      (arabic.bodyMedium!, latin.bodyMedium!),
      (arabic.labelSmall!, latin.labelSmall!),
    ]) {
      expect(a.fontSize, l.fontSize);
      expect(a.fontWeight, l.fontWeight);
      expect(a.height, closeTo((l.height! + NazzilTheme.arabicLead) * NazzilTheme.arabicScale, 1e-9));
    }
    // The percentage is digits only, so it is one thing in both languages.
    expect(arabic.displayLarge, latin.displayLarge);
  });

  test('a run of the other script is set as that script is, from either side', () {
    final latin = NazzilTheme.dark(NazzilPalette.rose, arabic: false).textTheme;
    final arabic = NazzilTheme.dark(NazzilPalette.rose, arabic: true).textTheme;
    for (final (a, l) in [
      (arabic.headlineMedium!, latin.headlineMedium!),
      (arabic.bodyLarge!, latin.bodyLarge!),
      (arabic.labelMedium!, latin.labelMedium!),
    ]) {
      // An Arabic title in the English app reads as it does in the Arabic app, and the other way round.
      final there = NazzilTheme.inScript(l, arabic: true);
      expect(there.fontFamily, a.fontFamily);
      expect(there.fontFamilyFallback, a.fontFamilyFallback);
      expect(there.fontSize, a.fontSize);
      expect(there.height, closeTo(a.height!, 1e-9));
      final back = NazzilTheme.inScript(a, arabic: false);
      expect(back.fontFamily, l.fontFamily);
      expect(back.fontFamilyFallback, l.fontFamilyFallback);
      expect(back.height, closeTo(l.height!, 1e-9));
      // Asked for the script it is already set for, a style stays as it is.
      expect(NazzilTheme.inScript(l, arabic: false), same(l));
      expect(NazzilTheme.inScript(a, arabic: true), same(a));
    }
  });

  test('the percentage counts without shaking: its figures are of one width', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadShippedTypefaces();
    final style = NazzilTheme.dark(NazzilPalette.rose, arabic: true).textTheme.displayLarge!;
    double wide(String text) {
      final painter = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    // The serif draws a 1 narrower than a 0. Left so, every step would push the sign along.
    expect({for (var figure = 0; figure <= 9; figure++) wide('$figure')}, hasLength(1));
    expect(wide('11%'), wide('80%'));
  });
}

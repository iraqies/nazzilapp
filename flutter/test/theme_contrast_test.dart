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
  for (final brightness in Brightness.values) {
    final theme = brightness == Brightness.dark ? NazzilTheme.dark(arabic: false) : NazzilTheme.light(arabic: false);
    final scheme = theme.colorScheme;
    final surfaces = {
      'page': scheme.surface,
      'sheet': scheme.surfaceContainerLow,
      'raised': scheme.surfaceContainerHigh,
    };

    test('${brightness.name}: text passes 4.5:1 on every surface', () {
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
      // The button that does the next step is the tint; its white words carry the contrast.
      expect(scheme.primaryContainer, NazzilColors.tint);
      expect(scheme.onPrimaryContainer, NazzilColors.onTint);
      expect(ratio(scheme.onPrimaryContainer, scheme.primaryContainer), greaterThanOrEqualTo(4.5));
      // A picked choice is filled with the text colour and written in the page colour.
      expect(ratio(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(4.5));
      expect(ratio(scheme.onInverseSurface, scheme.inverseSurface), greaterThanOrEqualTo(4.5));
    });

    test('${brightness.name}: control edges and the picked choice pass 3:1', () {
      for (final surface in surfaces.entries) {
        expect(ratio(scheme.outline, surface.value), greaterThanOrEqualTo(3), reason: 'edge on ${surface.key}');
        expect(ratio(scheme.primary, surface.value), greaterThanOrEqualTo(3), reason: 'picked on ${surface.key}');
      }
    });

    test('${brightness.name}: the interface itself has no colour', () {
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

  test('english is set in Inter and arabic in IBM Plex Sans Arabic, each behind the other', () {
    for (final arabic in [false, true]) {
      final type = NazzilTheme.dark(arabic: arabic).textTheme;
      for (final style in stylesOf(type)) {
        // The percentage is digits, so it stays Latin even in the Arabic app.
        final latinFirst = !arabic || style == type.displayLarge;
        // A word in the other script falls through to the other typeface, so neither is ever
        // left to whatever the phone has.
        expect(style.fontFamily, latinFirst ? NazzilTheme.sans : NazzilTheme.arabicSans);
        expect(style.fontFamilyFallback, [latinFirst ? NazzilTheme.arabicSans : NazzilTheme.sans]);
        expect(style.fontWeight, anyOf(FontWeight.w400, NazzilTheme.strong, NazzilTheme.bold, NazzilTheme.heavy));
        // Spacing between letters breaks the joins of Arabic, so only Latin is drawn tight,
        // as Finery sets its headlines, and nothing is spaced out.
        expect(style.letterSpacing, latinFirst ? lessThanOrEqualTo(0) : 0);
        expect(style.wordSpacing, isNull, reason: 'each typeface spaces its own words');
      }
    }
  });

  test('the app ships the typefaces it sets, in the weights it sets them', () {
    final shipped = shippedTypefaces();
    expect(shipped.keys, unorderedEquals([NazzilTheme.sans, NazzilTheme.arabicSans]));
    Set<int> weights(String family) => {for (final file in shipped[family]!) typefaceFacts(file).weight};
    final set = {
      for (final arabic in [false, true])
        for (final style in stylesOf(NazzilTheme.dark(arabic: arabic).textTheme)) style.fontWeight!.value,
      NazzilTheme.bold.value,
    };
    // A weight that is not shipped would be faked by the screen, by smearing the letters.
    expect(weights(NazzilTheme.sans), set);
    // Plex Arabic is drawn no heavier than bold, which then answers for extra bold too:
    // a screen smears a face only when it is asked for 200 or more above it.
    expect(weights(NazzilTheme.arabicSans), {400, NazzilTheme.strong.value, NazzilTheme.bold.value});
    for (final weight in set) {
      final answer = weights(NazzilTheme.arabicSans).where((w) => w <= weight).reduce(math.max);
      expect(weight - answer, lessThan(200), reason: 'Arabic set at $weight is drawn from the face at $answer');
    }
    expect(NazzilTheme.strong.value, greaterThan(500), reason: 'at 500 or less a screen picks the regular');
  });

  test('both typefaces are drawn to sit on one line at one size', () {
    final shipped = shippedTypefaces();
    final files = [...shipped[NazzilTheme.sans]!, ...shipped[NazzilTheme.arabicSans]!].map(typefaceFacts);
    for (final f in files) {
      // Each face reaches above and below the line and is drawn on a real body,
      // so the theme can set both scripts at the same size with no enlargement.
      expect(f.above, greaterThan(0));
      expect(f.below, greaterThan(0));
      expect(f.body, greaterThanOrEqualTo(1000));
    }
    // The theme asks for no enlargement and no extra lead between the two scripts.
    expect(NazzilTheme.arabicScale, 1.0);
    expect(NazzilTheme.arabicLead, 0.0);
  });

  test('one text size suits both scripts, set on the same lines', () {
    final latin = NazzilTheme.dark(arabic: false).textTheme;
    final arabic = NazzilTheme.dark(arabic: true).textTheme;
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
    final latin = NazzilTheme.dark(arabic: false).textTheme;
    final arabic = NazzilTheme.dark(arabic: true).textTheme;
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
    final style = NazzilTheme.dark(arabic: true).textTheme.displayLarge!;
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

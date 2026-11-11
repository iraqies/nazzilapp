import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nazzil/theme/nazzil_theme.dart';

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

  test('latin is set in Archivo and arabic falls through to Changa, in both languages', () {
    for (final arabic in [false, true]) {
      final type = NazzilTheme.dark(NazzilPalette.rose, arabic: arabic).textTheme;
      for (final style in [
        type.displayLarge,
        type.displaySmall,
        type.headlineMedium,
        type.headlineSmall,
        type.titleLarge,
        type.titleMedium,
        type.titleSmall,
        type.bodyLarge,
        type.bodyMedium,
        type.bodySmall,
        type.labelLarge,
        type.labelMedium,
        type.labelSmall,
      ]) {
        expect(style?.fontFamily, 'Archivo');
        expect(style?.fontFamilyFallback, ['Changa']);
        // The Archivo file opens at weight 600 unless told, so every style names its weight and width.
        final axes = {for (final FontVariation axis in style!.fontVariations!) axis.axis: axis.value};
        expect(axes.keys, containsAll(['wght', 'wdth']));
        expect(axes['wght'], style.fontWeight!.value.toDouble());
        expect(style.letterSpacing, 0);
      }
      // Changa goes up to 800, so Arabic headings keep the weight of the Latin ones.
      expect(type.displaySmall?.fontWeight, FontWeight.w800);
    }
  });

  test('arabic lines are taller, and its largest heading is a size down', () {
    final latin = NazzilTheme.dark(NazzilPalette.rose, arabic: false).textTheme;
    final arabic = NazzilTheme.dark(NazzilPalette.rose, arabic: true).textTheme;
    expect(arabic.bodyMedium!.height, greaterThan(latin.bodyMedium!.height!));
    expect(arabic.displaySmall!.fontSize, lessThan(latin.displaySmall!.fontSize!));
    // The percentage is digits only, and keeps its tight line in both.
    expect(arabic.displayLarge!.height, latin.displayLarge!.height);
  });
}

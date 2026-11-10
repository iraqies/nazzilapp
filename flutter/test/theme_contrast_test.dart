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
        'card': scheme.surfaceContainerLow,
        'raised': scheme.surfaceContainerHigh,
      };

      test('${palette.id} ${brightness.name}: text passes 4.5:1 on every surface', () {
        final inks = {
          'text': scheme.onSurface,
          'muted': scheme.onSurfaceVariant,
          'brand': scheme.primary,
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
        expect(ratio(scheme.onPrimaryContainer, scheme.primaryContainer), greaterThanOrEqualTo(4.5));
        expect(ratio(scheme.onInverseSurface, scheme.inverseSurface), greaterThanOrEqualTo(4.5));
      });

      test('${palette.id} ${brightness.name}: control edges and picked states pass 3:1', () {
        for (final surface in surfaces.entries) {
          expect(ratio(scheme.outline, surface.value), greaterThanOrEqualTo(3), reason: 'outline on ${surface.key}');
        }
        // A picked cell is the fill with a brand-tone edge; one of the two
        // must stand out from the card it sits on.
        final card = scheme.surfaceContainerLow;
        expect(
          math.max(ratio(scheme.primaryContainer, card), ratio(scheme.primary, card)),
          greaterThanOrEqualTo(3),
        );
      });
    }
  }

  test('white text on the photo scrim passes 4.5:1 even over a white photo', () {
    final worst = Color.alphaBlend(NazzilColors.photoScrim, Colors.white);
    expect(ratio(Colors.white, worst), greaterThanOrEqualTo(4.5));
  });

  test('latin is set in Outfit and arabic falls through to Noto Naskh Arabic, in both languages', () {
    for (final arabic in [false, true]) {
      final type = NazzilTheme.dark(NazzilPalette.rose, arabic: arabic).textTheme;
      for (final style in [
        type.displaySmall,
        type.headlineMedium,
        type.titleLarge,
        type.titleMedium,
        type.bodyLarge,
        type.bodyMedium,
        type.bodySmall,
        type.labelLarge,
        type.labelMedium,
      ]) {
        expect(style?.fontFamily, 'Outfit');
        expect(style?.fontFamilyFallback, ['NotoNaskhArabic']);
      }
    }
    // Noto Naskh Arabic stops at bold, so the Arabic styles do too.
    expect(NazzilTheme.dark(NazzilPalette.rose, arabic: true).textTheme.displaySmall?.fontWeight, FontWeight.w700);
  });
}

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nazzil/l10n/strings.dart';

void main() {
  test('an Arabic count takes the form its number asks for', () {
    const s = S('ar');
    expect(
      [for (final n in [0, 1, 2, 3, 10, 11, 16, 99, 100, 102, 103, 111]) s.itemsN(n)],
      [
        'لا عناصر',
        'عنصر واحد',
        'عنصران',
        '3 عناصر',
        '10 عناصر',
        '11 عنصرًا',
        '16 عنصرًا',
        '99 عنصرًا',
        '100 عنصر',
        '102 عنصر',
        '103 عناصر',
        '111 عنصرًا',
      ],
    );
    expect(
      [for (final n in [0, 1, 2, 3, 10, 11, 25, 100]) s.photosN(n)],
      ['لا صور', 'صورة واحدة', 'صورتان', '3 صور', '10 صور', '11 صورة', '25 صورة', '100 صورة'],
    );
    expect(s.waitingN(2), '2 قيد الانتظار');
  });

  test('an English count has one form for one and one for the rest', () {
    const s = S('en');
    expect([s.itemsN(0), s.itemsN(1), s.itemsN(2)], ['0 items', '1 item', '2 items']);
    expect([s.photosN(1), s.photosN(12)], ['1 photo', '12 photos']);
    expect([s.waitingN(1), s.waitingN(3)], ['1 waiting', '3 waiting']);
  });

  test('a percentage shows its sign on the same side after Arabic words as it does alone', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const s = S('ar');
    // How far right of the digit the sign is drawn, in a line that runs right to left.
    double signPastDigit(String line) {
      final painter = TextPainter(
        text: TextSpan(text: line, style: const TextStyle(fontSize: 20)),
        textDirection: TextDirection.rtl,
      )..layout();
      double left(String char) {
        final at = line.indexOf(char);
        return painter.getBoxesForSelection(TextSelection(baseOffset: at, extentOffset: at + 1)).first.left;
      }

      return left('%') - left('8');
    }

    expect(signPastDigit(s.percent(8)), greaterThan(0));
    expect(signPastDigit('${s.downloading} ${s.percent(8)}'), greaterThan(0));
    expect(const S('en').percent(8), '8%');
  });

  // The owner's call on 2026-11-11: standard Arabic, not Iraqi dialect.
  test('the Arabic is standard Arabic: no word of the Iraqi dialect is in it', () {
    final source = File('lib/l10n/strings.dart').readAsStringSync();
    final lines = [
      for (final match in RegExp(r"'([^'\n]*[\u0600-\u06FF][^'\n]*)'").allMatches(source)) match.group(1)!,
    ];
    expect(lines.length, greaterThan(100), reason: 'the Arabic lines were found in the source');
    const dialect = {
      'ماكو', 'أكو', 'مو', 'شي', 'ويّا', 'ويا', 'قاعد', 'اللي', 'بس', 'هذي', 'شوية', 'بعدين', 'هسه', 'شنو', 'شلون', 'وين',
      'كدرت', 'جيب', 'ضيف', 'لصّق', 'وقّف', 'كمّل', 'سكّر', 'اختار', 'انحذف', 'انحفظ', 'انحفظت', 'بيه', 'النت', 'بتلفونك',
    };
    final found = [
      for (final line in lines)
        for (final word in line.split(RegExp(r'[^\u0600-\u06FF]+')))
          if (dialect.contains(word)) '$word in "$line"',
    ];
    expect(found, isEmpty);
  });
}

import '../models/marking_code.dart';
import '../utils/km_logger.dart';

/// Maximum number of non-empty marking lines per file.
const int kmMaxLines = 10000;

/// If [serial] ever contains the literal substring `91` before the real AI 91,
/// this non-greedy split will mis-parse; such cases need a different strategy.
final RegExp _kmPattern = RegExp(r'^01(\d{14})21(.+?)91(.{4})92(.+)$');

/// Removes whitespace, **ASCII GS1 transport separators** (FS/GS/RS/US
/// `\x1C`–`\x1F`, often `\x1D` = GS between AI в экспорте Честного ЗНАКа), and
/// common invisible Unicode; strips BOM so `01` is first.
String normalizeKmLine(String line) {
  var s = line.trim();
  // Файлы из систем маркировки иногда содержат GS (0x1D) между полями — для
  // HRI-регекса «0101…21…91…92» их нужно убрать (в символ Data Matrix они
  // всё равно попадут через DataMatrixEncoder..gs()).
  s = s.replaceAll(RegExp(r'[\x00-\x1F\x7F]+'), '');
  s = s.replaceAll(
    RegExp(r'[\s\uFEFF\u00A0\u200B-\u200D\u2060\u202F]+'),
    '',
  );
  const bom = '\uFEFF';
  while (s.startsWith(bom)) {
    s = s.substring(bom.length);
  }
  return s;
}

/// Короткая диагностика, почему строка может не подойти под шаблон.
String describeKmLineIssues(String normalized, int fileLine) {
  final buf = StringBuffer('диагностика строки $fileLine:\n');
  buf.writeln('- длина после нормализации: ${normalized.length}');
  if (normalized.isEmpty) {
    buf.writeln('- строка пустая после удаления пробелов');
    return buf.toString();
  }
  final first = normalized.codeUnitAt(0);
  buf.writeln(
    '- первый символ: U+${first.toRadixString(16).toUpperCase().padLeft(4, '0')} «${normalized[0]}»',
  );
  buf.writeln('- начинается с "01": ${normalized.startsWith('01')}');
  if (normalized.length >= 16) {
    final after01 = normalized.substring(2, 16);
    final gtinOk = RegExp(r'^\d{14}$').hasMatch(after01);
    buf.writeln('- 14 символов после 01 (GTIN): "$after01" (все цифры: $gtinOk)');
    if (normalized.length >= 18) {
      buf.writeln('- позиции 16–17 (ожидается "21"): "${normalized.substring(16, 18)}"');
    } else if (normalized.length > 16) {
      buf.writeln('- с позиции 16 (ожид. "21"): "${normalized.substring(16)}"');
    }
  } else {
    buf.writeln('- слишком короткая для GTIN+21');
  }
  final i92 = normalized.indexOf('92');
  final i91 = normalized.indexOf('91');
  buf.writeln('- первый индекс "91": $i91, первый индекс "92": $i92');
  if (i91 >= 0) {
    final end = (i91 + 6 <= normalized.length) ? i91 + 6 : normalized.length;
    if (end > i91) {
      final slice = normalized.substring(i91, end);
      final codes = slice.codeUnits
          .map((u) => 'U+${u.toRadixString(16).toUpperCase().padLeft(4, '0')}')
          .join(' ');
      buf.writeln('- code units после первого "91" (${slice.length} симв.): $codes');
    }
  }
  if (i91 >= 0 && i92 > i91) {
    final between = normalized.substring(i91, i92 < normalized.length ? i92 + 2 : normalized.length);
    buf.writeln('- фрагмент от первого "91" до "92"+2: ${between.length > 80 ? '${between.substring(0, 80)}…' : between}');
  }
  return buf.toString();
}

/// Splits [text] into lines, trims, drops empties, parses each as КМ.
List<MarkingCode> parseMarkingFile(String text) {
  final lines = text.split(RegExp(r'\r?\n'));
  final nonEmpty = <String>[];
  final rawTrimmed = <String>[];
  final lineIndices = <int>[];

  kmLog(
    'parseMarkingFile: всего строк в файле (после split): ${lines.length}, '
    'длина текста: ${text.length} символов',
  );

  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i].trim();
    final t = normalizeKmLine(raw);
    if (t.isEmpty) {
      continue;
    }
    nonEmpty.add(t);
    rawTrimmed.add(raw);
    lineIndices.add(i + 1);
  }

  kmLog('непустых строк после trim+удаление пробелов: ${nonEmpty.length}');

  if (nonEmpty.isEmpty) {
    kmLog('ошибка: нет ни одной непустой строки');
    throw KmParseException('В файле нет ни одной непустой строки с кодом.');
  }
  if (nonEmpty.length > kmMaxLines) {
    kmLog('ошибка: слишком много строк ${nonEmpty.length}');
    throw KmParseException(
      'Слишком много кодов: ${nonEmpty.length}. Допустимо не более $kmMaxLines.',
    );
  }

  final out = <MarkingCode>[];
  for (var j = 0; j < nonEmpty.length; j++) {
    final line = nonEmpty[j];
    final fileLine = lineIndices[j];
    final raw = rawTrimmed[j];

    if (j == 0) {
      kmLog(
        'пример строки 1: raw(trim)=«${raw.length > 200 ? '${raw.substring(0, 200)}…' : raw}»',
      );
      kmLog(
        'пример строки 1: normalized длина=${line.length} '
        'начало=«${line.length > 120 ? '${line.substring(0, 120)}…' : line}»',
      );
    }

    final m = _kmPattern.firstMatch(line);
    if (m == null) {
      kmLog('ОШИБКА парсинга: строка файла #$fileLine не совпала с regex');
      kmLog('raw(trim), длина=${raw.length}: «$raw»');
      kmLog('normalized, длина=${line.length}: «$line»');
      kmLog(describeKmLineIssues(line, fileLine));
      final details = StringBuffer()
        ..writeln('raw(trim), длина=${raw.length}:')
        ..writeln(raw)
        ..writeln()
        ..writeln('normalized, длина=${line.length}:')
        ..writeln(line)
        ..writeln()
        ..write(describeKmLineIssues(line, fileLine));

      throw KmParseException(
        'Строка $fileLine: неверный формат КМ (ожидается 01+GTIN+21+серия+91+4+92+криптохвост). '
        'Подробности ниже на экране и в консоли [qrcode_km].',
        details: details.toString(),
      );
    }
    out.add(
      MarkingCode(
        gtin14: m.group(1)!,
        serial: m.group(2)!,
        keyId91: m.group(3)!,
        crypto92: m.group(4)!,
        lineIndex: fileLine,
      ),
    );
  }

  kmLog('успех: распознано кодов ${out.length}');
  return out;
}

class KmParseException implements Exception {
  KmParseException(this.message, {this.details});
  final String message;
  final String? details;

  @override
  String toString() =>
      details != null && details!.isNotEmpty ? '$message\n\n$details' : message;
}

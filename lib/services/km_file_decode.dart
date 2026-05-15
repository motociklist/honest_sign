import 'dart:convert';
import 'dart:typed_data';

import 'km_parser.dart' show normalizeKmLine;
import '../utils/km_logger.dart';

/// Первая непустая строка похожа на КМ (после [normalizeKmLine] начинается с `01`).
bool _firstLineLooksLikeKm(String text) {
  for (final line in text.split(RegExp(r'\r?\n'))) {
    final n = normalizeKmLine(line);
    if (n.isEmpty) {
      continue;
    }
    return n.startsWith('01') && n.length >= 18;
  }
  return false;
}

String _decodeUtf16Le(Uint8List bytes) {
  if (bytes.isEmpty) {
    return '';
  }
  final len = bytes.length - (bytes.length % 2);
  final out = Uint16List(len ~/ 2);
  for (var i = 0; i < len; i += 2) {
    out[i ~/ 2] = bytes[i] | (bytes[i + 1] << 8);
  }
  return String.fromCharCodes(out);
}

String _decodeUtf16Be(Uint8List bytes) {
  if (bytes.isEmpty) {
    return '';
  }
  final len = bytes.length - (bytes.length % 2);
  final out = Uint16List(len ~/ 2);
  for (var i = 0; i < len; i += 2) {
    out[i ~/ 2] = (bytes[i] << 8) | bytes[i + 1];
  }
  return String.fromCharCodes(out);
}

/// Декодирует байты .txt: UTF-8, при необходимости UTF-16 LE/BE (часто из Блокнота Windows).
String decodeMarkingFileBytes(Uint8List input) {
  var bytes = input;
  if (bytes.length >= 3 &&
      bytes[0] == 0xef &&
      bytes[1] == 0xbb &&
      bytes[2] == 0xbf) {
    kmLog('декод: снят UTF-8 BOM (EF BB BF)');
    bytes = bytes.sublist(3);
  }

  final utf8Text = utf8.decode(bytes, allowMalformed: true);
  if (_firstLineLooksLikeKm(utf8Text)) {
    kmLog('декод: использован UTF-8');
    return utf8Text;
  }

  kmLog(
    'декод: UTF-8 не похож на КМ (первая непустая строка не начинается с 01 после нормализации), '
    'пробуем UTF-16…',
  );

  if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe) {
    final t = _decodeUtf16Le(bytes.sublist(2));
    if (_firstLineLooksLikeKm(t)) {
      kmLog('декод: UTF-16 LE с BOM (FF FE)');
      return t;
    }
  }

  final leNoBom = _decodeUtf16Le(bytes);
  if (_firstLineLooksLikeKm(leNoBom)) {
    kmLog('декод: UTF-16 LE без BOM');
    return leNoBom;
  }

  if (bytes.length >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff) {
    final t = _decodeUtf16Be(bytes.sublist(2));
    if (_firstLineLooksLikeKm(t)) {
      kmLog('декод: UTF-16 BE с BOM (FE FF)');
      return t;
    }
  }

  final beNoBom = _decodeUtf16Be(bytes);
  if (_firstLineLooksLikeKm(beNoBom)) {
    kmLog('декод: UTF-16 BE без BOM');
    return beNoBom;
  }

  kmLog('декод: fallback UTF-8 (allowMalformed) — проверьте кодировку файла (желательно UTF-8)');
  return utf8Text;
}

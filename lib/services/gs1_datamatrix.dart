import 'dart:typed_data';

import 'package:barcode/barcode.dart';

import '../models/marking_code.dart';
import '../utils/km_logger.dart';

/// Raw GS1 element string as a scanner typically outputs it before HRI formatting.
///
/// AI 01 has fixed length (14 digits), so there must be **no** GS separator
/// between GTIN and AI 21. Variable-length fields are separated with GS.
String gs1RawScannerText(MarkingCode km) =>
    '01${km.gtin14}21${km.serial}\x1D91${km.keyId91}\x1D92${km.crypto92}';

/// Builds GS1 DataMatrix payload bytes: FNC1 + element string with GS separators.
Uint8List gs1DataMatrixPayload(MarkingCode km) {
  // GS must be encoded as an ASCII character (0x1D) in Data Matrix ASCII
  // encodation, not inserted as a raw codeword. DataMatrixEncoder.ascii()
  // converts it to the correct Data Matrix codeword.
  final enc = DataMatrixEncoder()
    ..fnc1()
    ..ascii('01')
    ..ascii(km.gtin14)
    ..ascii('21')
    ..ascii(km.serial)
    ..ascii('\x1D')
    ..ascii('91')
    ..ascii(km.keyId91)
    ..ascii('\x1D')
    ..ascii('92')
    ..ascii(km.crypto92);
  return enc.toBytes();
}

void verifyGs1DataMatrixPayload(Uint8List payload, {int? lineIndex}) {
  try {
    Barcode.dataMatrix().verifyBytes(payload);
  } catch (e, st) {
    kmLog(
      'verifyGs1DataMatrixPayload FAIL line=$lineIndex len=${payload.length}',
      error: e,
      stackTrace: st,
    );
    rethrow;
  }
}

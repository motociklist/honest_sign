import 'package:barcode/barcode.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qrcode/services/gs1_datamatrix.dart';
import 'package:qrcode/services/km_parser.dart';
import 'package:qrcode/services/pdf_export_service.dart';

void main() {
  test('parse sample KM, verify Data Matrix payload, build PDF', () async {
    const sample =
        '0104812305007518215bpqAc=uspNLh91EE119278Tv27H0PLbQdq17P4/9XH9aAxsC076guxdesAraVx4=';
    final codes = parseMarkingFile(sample);
    expect(codes.length, 1);
    expect(codes.single.gtin14, '04812305007518');
    expect(codes.single.keyId91, 'EE11');
    expect(
      gs1RawScannerText(codes.single),
      '0104812305007518215bpqAc=uspNLh\x1D91EE11\x1D9278Tv27H0PLbQdq17P4/9XH9aAxsC076guxdesAraVx4=',
    );
    final payload = gs1DataMatrixPayload(codes.single);
    expect(payload, contains(0x1e)); // ASCII GS (0x1D) encoded by Data Matrix ASCII.
    expect(payload, isNot(contains(0x1d))); // Do not insert raw GS as a codeword.
    expect(() => Barcode.dataMatrix().verifyBytes(payload), returnsNormally);
    final pdf = await generateMarkingPdfBytes(codes);
    expect(pdf.isNotEmpty, isTrue);
    expect(pdf.lengthInBytes > 500, isTrue);
  });

  test('parse KM with spaces between AI blocks (Честный ЗНАК export style)', () {
    const spaced =
        '0104812305007518215bpqAc=uspNLh 91EE11 9278Tv27H0PLbQdql7P4/9XH9aAxsC076guxdesAraVx4=';
    final codes = parseMarkingFile(spaced);
    expect(codes.length, 1);
    expect(codes.single.gtin14, '04812305007518');
    expect(codes.single.serial, '5bpqAc=uspNLh');
    expect(codes.single.keyId91, 'EE11');
    expect(codes.single.crypto92, startsWith('78Tv27'));
  });

  test('parse KM with GS1 ASCII separators GS 0x1D between AIs (export)', () {
    const gs = '\x1D';
    final line =
        '0104812305007518215bpqAc=uspNLh${gs}91EE11${gs}9278Tv27H0PLbQdq17P4/9XH9aAxsC076guxdesAraVx4=';
    final codes = parseMarkingFile(line);
    expect(codes.length, 1);
    expect(codes.single.gtin14, '04812305007518');
    expect(codes.single.serial, '5bpqAc=uspNLh');
    expect(codes.single.keyId91, 'EE11');
    expect(codes.single.crypto92, startsWith('78Tv27'));
  });
}

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:qrcode/services/km_file_decode.dart';
import 'package:qrcode/services/km_parser.dart';

void main() {
  test('decode UTF-16 LE with BOM (Notepad Windows)', () {
    const ascii = '0104812305007518215ab91EE1192cd=';
    final units = ascii.codeUnits;
    final bytes = Uint8List(2 + units.length * 2);
    bytes[0] = 0xff;
    bytes[1] = 0xfe;
    for (var i = 0; i < units.length; i++) {
      final u = units[i];
      bytes[2 + i * 2] = u & 0xff;
      bytes[2 + i * 2 + 1] = (u >> 8) & 0xff;
    }
    final text = decodeMarkingFileBytes(bytes);
    final codes = parseMarkingFile(text);
    expect(codes.length, 1);
    expect(codes.single.gtin14, '04812305007518');
    expect(codes.single.serial, '5ab');
    expect(codes.single.keyId91, 'EE11');
    expect(codes.single.crypto92, 'cd=');
  });
}

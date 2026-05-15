import 'package:flutter_test/flutter_test.dart';

import 'package:qrcode/models/marking_code.dart';

void main() {
  test('gs1HumanReadable matches GS1 HRI with parentheses', () {
    const km = MarkingCode(
      gtin14: '04812305007518',
      serial: '5uE.Z9el)0Tjp',
      keyId91: 'EE11',
      crypto92: 'HrpiNcr9h/zgc5JRYG3jG2xGGO6KpCa6MtVFJLgfYtY=',
      lineIndex: 1,
    );
    expect(
      km.gs1HumanReadable,
      '(01)04812305007518(21)5uE.Z9el)0Tjp(91)EE11(92)HrpiNcr9h/zgc5JRYG3jG2xGGO6KpCa6MtVFJLgfYtY=',
    );
  });
}

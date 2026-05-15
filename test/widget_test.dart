import 'package:flutter_test/flutter_test.dart';

import 'package:qrcode/main.dart';

void main() {
  testWidgets('Home screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('КМ → GS1 DataMatrix → PDF'), findsOneWidget);
    expect(find.text('Выбрать файл .txt'), findsOneWidget);
  });
}

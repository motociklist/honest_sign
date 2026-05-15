/// Parsed marking code (КМ) fields from a single HRI line.
class MarkingCode {
  const MarkingCode({
    required this.gtin14,
    required this.serial,
    required this.keyId91,
    required this.crypto92,
    required this.lineIndex,
  });

  final String gtin14;
  final String serial;
  final String keyId91;
  final String crypto92;
  final int lineIndex;

  /// Человекочитаемое представление по GS1 (скобки вокруг AI) — для тестов/интеграций.
  /// В PDF не печатается; при сканировании вид строки задаёт **приложение сканера** (режим GS1 / HRI).
  String get gs1HumanReadable =>
      '(01)$gtin14(21)$serial(91)$keyId91(92)$crypto92';
}

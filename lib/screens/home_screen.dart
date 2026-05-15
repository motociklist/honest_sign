import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/marking_code.dart';
import '../services/gs1_datamatrix.dart';
import '../utils/km_logger.dart';
import '../services/km_file_decode.dart';
import '../services/km_parser.dart';
import '../services/pdf_export_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _pickedName;
  List<MarkingCode>? _codes;
  Uint8List? _pdfBytes;
  bool _busy = false;
  String? _error;
  String? _errorDetails;

  Future<void> _pickAndParse() async {
    setState(() {
      _error = null;
      _errorDetails = null;
      _codes = null;
      _pdfBytes = null;
    });
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt'],
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      kmLog('pickFiles: bytes == null для «${file.name}»');
      setState(() => _error = 'Не удалось прочитать файл.');
      return;
    }
    kmLog(
      'файл «${file.name}»: размер ${bytes.length} байт, '
      'расширение=${file.extension}',
    );
    try {
      final text = decodeMarkingFileBytes(bytes);
      if (text.isNotEmpty) {
        final previewLen = text.length > 160 ? 160 : text.length;
        kmLog(
          'первые $previewLen символов текста после декода:\n'
          '${text.substring(0, previewLen)}',
        );
      }
      final codes = parseMarkingFile(text);
      kmLog('проверка Data Matrix для ${codes.length} кодов…');
      for (var i = 0; i < codes.length; i++) {
        final c = codes[i];
        try {
          final payload = gs1DataMatrixPayload(c);
          if (i == 0) {
            kmLog(
              'строка ${c.lineIndex}: GTIN=${c.gtin14} serial.len=${c.serial.length} '
              '91=${c.keyId91} crypto92.len=${c.crypto92.length} payload.len=${payload.length}',
            );
          }
          verifyGs1DataMatrixPayload(payload, lineIndex: c.lineIndex);
        } on BarcodeException catch (e, st) {
          kmLog(
            'BarcodeException строка ${c.lineIndex}: ${e.message}',
            error: e,
            stackTrace: st,
          );
          throw KmParseException(
            'Строка ${c.lineIndex}: не удалось сформировать Data Matrix (${e.message}).',
            details:
                'Проверьте, что в строке нет лишних символов. Ошибка библиотеки barcode.\n$e',
          );
        }
      }
      kmLog('все коды прошли verifyBytes');
      setState(() {
        _pickedName = file.name;
        _codes = codes;
      });
    } on KmParseException catch (e, st) {
      kmLog('KmParseException: ${e.message}', error: e, stackTrace: st);
      setState(() {
        _error = e.message;
        _errorDetails = e.details;
      });
    }
  }

  Future<void> _generatePdf() async {
    final codes = _codes;
    if (codes == null || codes.isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _errorDetails = null;
      _pdfBytes = null;
    });
    kmLog('generatePdf: старт, кодов=${codes.length}');
    try {
      final pdf = await generateMarkingPdfBytes(codes);
      kmLog('generatePdf: готово, размер PDF=${pdf.length} байт');
      if (!mounted) {
        return;
      }
      setState(() {
        _pdfBytes = pdf;
        _busy = false;
      });
    } catch (e, st) {
      kmLog('generatePdf: ошибка', error: e, stackTrace: st);
      debugPrintStack(stackTrace: st);
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = 'Ошибка при создании PDF: $e';
      });
    }
  }

  Future<void> _savePdf() async {
    final pdf = _pdfBytes;
    if (pdf == null) {
      return;
    }
    final base = (_pickedName ?? 'km')
        .replaceAll(RegExp(r'\.[^.]+$'), '')
        .replaceAll(RegExp(r'[^\w\-]+'), '_');
    try {
      await FileSaver.instance.saveFile(
        name: '${base}_datamatrix',
        bytes: pdf,
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF сохранён')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Сохранение: $e')),
      );
    }
  }

  Future<void> _sharePdf() async {
    final pdf = _pdfBytes;
    if (pdf == null) {
      return;
    }
    final base = (_pickedName ?? 'km').replaceAll(RegExp(r'\.[^.]+$'), '');
    final name = '${base}_datamatrix.pdf';
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            pdf,
            mimeType: 'application/pdf',
            name: name,
          ),
        ],
        subject: name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('КМ → GS1 DataMatrix → PDF'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _pickAndParse,
              icon: const Icon(Icons.folder_open),
              label: const Text('Выбрать файл .txt'),
            ),
            const SizedBox(height: 12),
            if (_pickedName != null)
              Text(
                'Файл: $_pickedName\nКодов: ${_codes?.length ?? 0}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: (_busy || _codes == null) ? null : _generatePdf,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf),
              label: Text(_busy ? 'Создание PDF…' : 'Создать PDF'),
            ),
            if (_codes != null && _codes!.length > 2000)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Большой список (${_codes!.length} шт.) — генерация может занять несколько минут.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 16),
            if (_pdfBytes != null) ...[
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _savePdf,
                      icon: const Icon(Icons.save),
                      label: const Text('Сохранить PDF'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _sharePdf,
                      icon: const Icon(Icons.share),
                      label: const Text('Поделиться'),
                    ),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      if (_errorDetails != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Техническая информация (можно скопировать):',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          _errorDetails!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ] else ...[
              const Spacer(),
            ],
            Text(
              'До $kmMaxLines кодов. Формат: 01+GTIN(14)+21+серия+91+4+92+криптохвост. '
              'Убираются пробелы, символ GS (U+001D) и другие управляющие символы между полями. '
              'Лучше UTF-8; Блокнот «Юникод» = UTF-16 — тоже поддерживается. '
              'Веб: F12 → Console, фильтр [qrcode_km] при flutter run.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

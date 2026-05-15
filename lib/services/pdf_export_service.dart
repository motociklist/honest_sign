import 'dart:isolate';
import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/marking_code.dart';
import '../utils/km_logger.dart';
import 'gs1_datamatrix.dart';

/// Builds a multi-page PDF: one GS1 DataMatrix per page and a 1-based index below.
///
/// На **вебе** `dart:isolate` недоступен — сборка идёт в текущем isolate (см.
/// [Document.save] `enableEventLoopBalancing`). На остальных платформах —
/// в отдельном isolate, чтобы не блокировать UI.
Future<Uint8List> generateMarkingPdfBytes(List<MarkingCode> codes) async {
  if (kIsWeb) {
    kmLog('PDF web: сборка ${codes.length} страниц в основном isolate…');
    return _buildMarkingPdf(codes);
  }
  return Isolate.run(() async => _buildMarkingPdf(codes));
}

Future<Uint8List> _buildMarkingPdf(List<MarkingCode> codes) async {
  kmLog('PDF: сборка ${codes.length} страниц…');
  final doc = pw.Document(
    title: 'Marking codes PDF',
    author: 'qrcode',
  );
  const pageFormat = PdfPageFormat(200, 236);
  for (var i = 0; i < codes.length; i++) {
    final km = codes[i];
    final pageNum = i + 1;
    final payload = gs1DataMatrixPayload(km);
    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.BarcodeWidget.fromBytes(
                  data: payload,
                  barcode: Barcode.dataMatrix(),
                  drawText: false,
                  width: 168,
                  height: 168,
                ),
                pw.SizedBox(height: 14),
                pw.Text(
                  '$pageNum',
                  style: const pw.TextStyle(fontSize: 16),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  final out = await doc.save(enableEventLoopBalancing: true);
  kmLog('PDF: готово, ${out.length} байт');
  return out;
}

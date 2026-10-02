// lib/utils/pdf_reports.dart
//
// Shared PDF export (BLUEPRINT.md 5.25) for Class Performance, Attendance
// and Admin Reports: centre header + optional summary lines + one table.
// `Printing.sharePdf()` downloads the file on Web and opens the share sheet
// on Android. Uses the PDF's built-in Helvetica font (no network font
// download), so keep generated text to plain ASCII - no emoji/bullets.

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<void> exportPdfReport({
  required String title,
  required String filename,
  String? subtitle,
  List<String> summaryLines = const [],
  required List<String> headers,
  required List<List<String>> rows,
}) async {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final generated =
      '${two(now.day)}/${two(now.month)}/${now.year} ${two(now.hour)}:${two(now.minute)}';

  final doc = pw.Document(title: title, author: 'TuturEdu');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Pusat Tuisyen Arena Matriks - TuturEdu',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          if (subtitle != null) pw.Text(subtitle),
          pw.Text(
            'Generated $generated',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
          pw.Divider(),
        ],
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        for (final line in summaryLines)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text(line),
          ),
        if (summaryLines.isNotEmpty) pw.SizedBox(height: 12),
        if (rows.isEmpty)
          pw.Text('No data.')
        else
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
            cellStyle: const pw.TextStyle(fontSize: 10),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            cellAlignment: pw.Alignment.centerLeft,
          ),
      ],
    ),
  );

  await Printing.sharePdf(bytes: await doc.save(), filename: filename);
}

/// Runs [export] with a spinner dialog up and a SnackBar on failure - every
/// screen's "Export PDF" button goes through this.
Future<void> runPdfExport(
  BuildContext context,
  Future<void> Function() export,
) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    await export();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not export PDF: $e')));
    }
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}

/// Safe filename fragment, e.g. "Add Maths Form 4" -> "Add_Maths_Form_4".
String pdfFileSlug(String value) => value
    .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');

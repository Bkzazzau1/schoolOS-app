import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'report_card_models.dart';

/// Renders an already-compiled [ReportCard] as a real, printable PDF document - on the device, from
/// data already synced locally, so this works even without a live connection. Every field here is
/// real and already reachable by whoever is allowed to see this card (apps/report_cards/visibility.py
/// on the server, mirrored by each role's own repository); nothing is invented for the document.
///
/// A report card that is not yet [ReportCardState.released] can still be rendered (useful for an
/// Administrator previewing one before release), but carries a visible "NOT YET RELEASED" notice so
/// it is never mistaken for the school's official copy.
Future<Uint8List> buildReportCardPdf({
  required ReportCard card,
  required String schoolName,
  Uint8List? logo,
}) async {
  final doc = pw.Document();
  final logoImage = logo != null ? pw.MemoryImage(logo) : null;

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(schoolName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text('Term Report Card', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              ]),
              if (logoImage != null) pw.Image(logoImage, width: 52, height: 52),
            ],
          ),
          if (card.state != ReportCardState.released) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(color: PdfColors.red100, borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Text(
                'NOT YET RELEASED - ${reportCardStateLabel(card.state).toUpperCase()}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red900),
              ),
            ),
          ],
          pw.SizedBox(height: 14),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 10),
          _kv('Student', card.studentName),
          _kv('Admission No.', card.admissionNumber),
          _kv('Class', card.section.isEmpty ? card.className : '${card.className} (${card.section})'),
          _kv('Term', card.term),
          if (card.attendancePercent != null) _kv('Attendance', '${card.attendancePercent}%'),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey500),
            columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1)},
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _cell('Subject', bold: true),
                  _cell('Score', bold: true),
                  _cell('Grade', bold: true),
                ],
              ),
              for (final line in card.subjects)
                pw.TableRow(children: [
                  _cell(line.subject),
                  _cell(line.percent == null ? 'Not recorded' : '${line.percent!.round()}%'),
                  _cell(line.grade.isEmpty ? '-' : line.grade),
                ]),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Overall average: ${card.overallAverage?.round() ?? '-'}%'
                '${card.overallGrade.isEmpty ? '' : ' (${card.overallGrade})'}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              if (card.classPosition != null) pw.Text('Position: ${card.classPosition} of ${card.classSize}'),
            ],
          ),
          if (card.classTeacherComment.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text("Class teacher's comment", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(card.classTeacherComment),
          ],
          if (card.principalComment.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text("Principal's comment", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(card.principalComment),
          ],
          if (card.releasedAt != null) ...[
            pw.SizedBox(height: 24),
            pw.Text(
              'Released ${card.releasedAt!.split('T').first}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ],
      ),
    ),
  );
  return doc.save();
}

pw.Widget _kv(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(children: [
        pw.SizedBox(width: 100, child: pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700))),
        pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ]),
    );

pw.Widget _cell(String text, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );

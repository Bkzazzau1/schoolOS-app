import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../familyfees/domain/family_fees_models.dart';

/// Renders one verified Smart Money Collection payment as a real, printable receipt - on the device,
/// from the same server-authoritative data [VerifiedCollectionsCard] already shows, never from a
/// locally-editable amount.
///
/// Only ever called for a payment [FamilyVerifiedPayment.countsTowardBalance] is true for: a reversed,
/// refunded, duplicate or otherwise unverified payment must never look like a successful one, so the
/// caller is expected to withhold the button rather than this function silently refusing - there is
/// nothing left to print once a payment has lost its allocations, since the fields below are plain.
Future<Uint8List> buildVerifiedPaymentReceiptPdf({
  required FamilyVerifiedPayment payment,
  required String schoolName,
  required String familyName,
}) async {
  final doc = pw.Document();
  final fullyMatched = payment.unappliedMinor == 0 && payment.creditMinor == 0 && payment.amountMinor == payment.allocatedMinor;

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(schoolName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text('PAYMENT RECEIPT', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Smart Money Collection · ${fullyMatched ? 'Fully allocated' : 'Partially allocated'}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 14),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 10),
          _kv('Family', familyName),
          _kv('Date', payment.dateLabel),
          _kv('Provider', payment.provider),
          _kv('Transaction reference', payment.reference),
          _kv('Amount received', _money(payment.amountMinor)),
          pw.SizedBox(height: 16),
          pw.Text('Where this payment went', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey500),
            columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(2), 2: pw.FlexColumnWidth(1)},
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [_cell('Student', bold: true), _cell('Item', bold: true), _cell('Amount', bold: true)],
              ),
              for (final a in payment.allocations) pw.TableRow(children: [_cell(a.studentName), _cell(a.item), _cell(_money(a.amountMinor))]),
              if (payment.creditMinor > 0)
                pw.TableRow(children: [_cell('-'), _cell('Held as family credit'), _cell(_money(payment.creditMinor))]),
            ],
          ),
          if (payment.unappliedMinor > 0) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              'Not yet applied: ${_money(payment.unappliedMinor)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red900),
            ),
          ],
          pw.SizedBox(height: 24),
          pw.Text(
            'This receipt is generated from a verified, provider-confirmed transfer. SkulGen does not receive or hold this money; '
            'it went straight to the school\'s own account.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

pw.Widget _kv(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(children: [
        pw.SizedBox(width: 130, child: pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700))),
        pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ]),
    );

pw.Widget _cell(String text, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );

// [amount] is whole kobo, same as every *Minor field the server sends: divide by 100 for naira.
// The PDF's built-in font has no naira glyph either (unlike the screen, which always has one), so
// "NGN" avoids a missing-character box on the printed receipt, where the amount matters most.
String _money(int amountMinor) {
  final negative = amountMinor < 0;
  final absolute = amountMinor.abs();
  final whole = (absolute ~/ 100).toString();
  final kobo = absolute % 100;
  final out = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final remaining = whole.length - i;
    out.write(whole[i]);
    if (remaining > 1 && remaining % 3 == 1) out.write(',');
  }
  final fraction = kobo == 0 ? '' : '.${kobo.toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}NGN $out$fraction';
}

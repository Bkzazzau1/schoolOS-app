import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../domain/report_card_models.dart';
import '../domain/report_card_pdf.dart';

/// Opens the platform's print/share/save sheet for [card] as a real PDF, built fresh on the device
/// from data already synced locally - so this works offline too.
class ReportCardPdfButton extends StatelessWidget {
  const ReportCardPdfButton({
    super.key,
    required this.card,
    required this.schoolName,
    this.logo,
    this.label = 'Download PDF',
  });

  final ReportCard card;
  final String schoolName;
  final Uint8List? logo;
  final String label;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: () => Printing.layoutPdf(
          onLayout: (format) => buildReportCardPdf(card: card, schoolName: schoolName, logo: logo),
          name: 'Report Card - ${card.studentName} - ${card.term}',
        ),
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: Text(label),
      );
}

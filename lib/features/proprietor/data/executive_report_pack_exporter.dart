import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'proprietor_reports_demo_data.dart';

class ExecutiveReportPackExporter {
  const ExecutiveReportPackExporter();

  Future<String> export({required String schoolName}) async {
    final directory = await getApplicationDocumentsDirectory();
    final safeSchool = schoolName
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '')
        .toLowerCase();
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final file = File(
      p.join(directory.path, '${safeSchool}_executive_report_pack_$date.txt'),
    );

    final buffer = StringBuffer()
      ..writeln('SchoolOS Executive Report Pack')
      ..writeln(schoolName)
      ..writeln('Generated: $date')
      ..writeln()
      ..writeln('OWNER KPI SNAPSHOT');

    for (final kpi in proprietorReportKpis) {
      buffer.writeln('${kpi.label}: ${kpi.value} — ${kpi.note}');
    }

    buffer
      ..writeln()
      ..writeln('AVAILABLE EXECUTIVE REPORTS');
    for (final report in proprietorExecutiveReports) {
      buffer.writeln(
        '- ${report.title} | ${report.coverage} | ${report.updated} | ${report.status}',
      );
    }

    buffer
      ..writeln()
      ..writeln('BOARD / OWNER PACK');
    for (final section in proprietorReportPackSections) {
      buffer.writeln(
        '${section.number}. ${section.title}: ${section.description}',
      );
    }

    buffer
      ..writeln()
      ..writeln('REPORT CADENCE');
    for (final cadence in proprietorReportCadence) {
      buffer.writeln(
        '${cadence.frequency}: ${cadence.reportType} — ${cadence.purpose}',
      );
    }

    buffer
      ..writeln()
      ..writeln('REPORTING PRINCIPLE')
      ..writeln(proprietorReportingPrinciple);

    await file.writeAsString(buffer.toString(), flush: true);
    return file.path;
  }
}

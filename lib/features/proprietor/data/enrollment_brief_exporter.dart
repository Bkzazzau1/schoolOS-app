import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'proprietor_enrollment_demo_data.dart';

class EnrollmentBriefExporter {
  const EnrollmentBriefExporter();

  Future<String> export({required String schoolName}) async {
    final directory = await getApplicationDocumentsDirectory();
    final safeSchool = schoolName
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '')
        .toLowerCase();
    final now = DateTime.now();
    final date = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final file = File(
      p.join(directory.path, '${safeSchool}_enrollment_brief_$date.txt'),
    );

    final buffer = StringBuffer()
      ..writeln('SchoolOS Enrollment Brief')
      ..writeln(schoolName)
      ..writeln('Generated: $date')
      ..writeln()
      ..writeln('EXECUTIVE SNAPSHOT');

    for (final kpi in proprietorEnrollmentKpis) {
      buffer.writeln('${kpi.label}: ${kpi.value} — ${kpi.note}');
    }

    buffer
      ..writeln()
      ..writeln('ADMISSIONS PIPELINE BY SECTION');

    for (final row in proprietorEnrollmentPipeline) {
      buffer.writeln(
        '${row.section}: ${row.applications} applications, ${row.offers} offers, '
        '${row.accepted} accepted, ${row.activeStudents} active students, '
        '${row.retentionPercent}% retention',
      );
    }

    buffer
      ..writeln()
      ..writeln('CAPACITY WATCH');

    for (final item in proprietorCapacityWatch) {
      buffer
        ..writeln('- ${item.title}')
        ..writeln('  ${item.detail}')
        ..writeln('  Action: ${item.action}');
    }

    buffer
      ..writeln()
      ..writeln('ENROLLMENT TREND')
      ..writeln(proprietorEnrollmentTrend.join(' → '))
      ..writeln()
      ..writeln('GOVERNANCE')
      ..writeln(
        'Admissions should follow eligibility, capacity and documented school policy. '
        'SchoolOS should not make opaque admissions decisions from family income, ethnicity, '
        'religion, disability, health history or other sensitive traits.',
      );

    await file.writeAsString(buffer.toString(), flush: true);
    return file.path;
  }
}

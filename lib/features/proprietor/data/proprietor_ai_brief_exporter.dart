import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'proprietor_ai_demo_data.dart';

class ProprietorAiBriefExporter {
  const ProprietorAiBriefExporter();

  Future<String> export({required String schoolName}) async {
    final directory = await getApplicationDocumentsDirectory();
    final safeSchool = schoolName
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '')
        .toLowerCase();
    final now = DateTime.now();
    final date = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final file = File(
      p.join(directory.path, '${safeSchool}_proprietor_ai_brief_$date.txt'),
    );

    final buffer = StringBuffer()
      ..writeln('SchoolOS Proprietor AI Executive Brief')
      ..writeln(schoolName)
      ..writeln('Generated: $date')
      ..writeln('Mode: Offline owner-authorized prototype context')
      ..writeln();

    for (final section in proprietorExecutiveBriefSections) {
      buffer.writeln(section.title.toUpperCase());
      for (final item in section.items) {
        buffer.writeln('- $item');
      }
      buffer.writeln();
    }

    buffer
      ..writeln('AI CONTEXT BOUNDARY')
      ..writeln(proprietorAiContextBoundary)
      ..writeln()
      ..writeln('DECISION BOUNDARY')
      ..writeln(proprietorAiDecisionBoundary);

    await file.writeAsString(buffer.toString(), flush: true);
    return file.path;
  }
}

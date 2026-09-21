import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/proprietor_ai_models.dart';
import 'proprietor_ai_text.dart';

/// The text of the executive brief.
String renderAiBrief({required String schoolName, required DateTime date, required List<ExecutiveBriefSection> sections}) {
  final day = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  final buffer = StringBuffer()
    ..writeln('SchoolOS Proprietor AI Executive Brief')
    ..writeln(schoolName)
    ..writeln('Generated: $day')
    ..writeln('Built from the records on this device. Nothing is estimated.')
    ..writeln();
  for (final section in sections) {
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
  return buffer.toString();
}

class ProprietorAiBriefExporter {
  const ProprietorAiBriefExporter();

  Future<String> export({required String schoolName, required List<ExecutiveBriefSection> sections}) async {
    final directory = await getApplicationDocumentsDirectory();
    final safeSchool = schoolName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '').toLowerCase();
    final now = DateTime.now();
    final date = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final file = File(p.join(directory.path, '${safeSchool}_proprietor_ai_brief_$date.txt'));
    await file.writeAsString(renderAiBrief(schoolName: schoolName, date: now, sections: sections), flush: true);
    return file.path;
  }
}

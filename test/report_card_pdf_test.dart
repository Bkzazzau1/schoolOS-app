import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/domain/report_card_models.dart';
import 'package:schoolos_app/features/administrator/domain/report_card_pdf.dart';

ReportCard _card({
  ReportCardState state = ReportCardState.released,
  List<ReportCardSubjectLine> subjects = const [],
  int? classPosition,
  String classTeacherComment = '',
  String principalComment = '',
  String? releasedAt = '2026-09-15T10:00:00Z',
}) =>
    ReportCard(
      id: 'RC-1',
      studentId: 'S1',
      studentName: 'Musa Ibrahim',
      admissionNumber: 'ADM-001',
      termId: 'T1',
      term: '2026/2027 · Term 1',
      className: 'Primary 4',
      section: 'Primary',
      state: state,
      subjects: subjects,
      overallAverage: 78,
      overallGrade: 'B',
      classPosition: classPosition,
      classSize: classPosition == null ? null : 30,
      attendancePercent: 92,
      principalComment: principalComment,
      classTeacherComment: classTeacherComment,
      releasedAt: releasedAt,
    );

void main() {
  test('a released report card renders as a real, non-empty PDF', () async {
    final bytes = await buildReportCardPdf(
      card: _card(subjects: const [
        ReportCardSubjectLine(classSubjectId: 'cs-1', subject: 'Mathematics', percent: 82, grade: 'A', assessmentsIncluded: 3),
        ReportCardSubjectLine(classSubjectId: 'cs-2', subject: 'English', percent: 70, grade: 'B', assessmentsIncluded: 2),
      ], classPosition: 4),
      schoolName: 'BrightGate Academy',
    );
    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('a subject with no recorded score still renders, not a crash', () async {
    final bytes = await buildReportCardPdf(
      card: _card(subjects: const [
        ReportCardSubjectLine(classSubjectId: 'cs-1', subject: 'Further Maths', percent: null, grade: '', assessmentsIncluded: 0),
      ]),
      schoolName: 'BrightGate Academy',
    );
    expect(bytes.length, greaterThan(500));
  });

  test('comments from the class teacher and principal are included without error', () async {
    final bytes = await buildReportCardPdf(
      card: _card(classTeacherComment: 'Good improvement this term.', principalComment: 'Keep up the effort.'),
      schoolName: 'BrightGate Academy',
    );
    expect(bytes.length, greaterThan(500));
  });

  test('a draft (not yet released) card still renders, with no release date to show', () async {
    final bytes = await buildReportCardPdf(
      card: _card(state: ReportCardState.draft, releasedAt: null),
      schoolName: 'BrightGate Academy',
    );
    expect(bytes.length, greaterThan(500));
  });

  test('a logo can be supplied without error', () async {
    // A minimal, real 1x1 PNG, so pw.MemoryImage can actually decode it.
    final onePixelPng = <int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
      0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
      0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D, 0xB0, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
      0x44, 0xAE, 0x42, 0x60, 0x82,
    ];
    final bytes = await buildReportCardPdf(
      card: _card(),
      schoolName: 'BrightGate Academy',
      logo: Uint8List.fromList(onePixelPng),
    );
    expect(bytes.length, greaterThan(500));
  });
}

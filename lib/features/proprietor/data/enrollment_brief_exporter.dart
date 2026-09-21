import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'owner_enrollment.dart';

/// Saves the enrollment brief (built from the real applicants and students) on the device.
class EnrollmentBriefExporter {
  const EnrollmentBriefExporter();

  Future<String> export({required String schoolName, required OwnerEnrollment enrollment}) async {
    final directory = await getApplicationDocumentsDirectory();
    final safeSchool = schoolName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '').toLowerCase();
    final now = DateTime.now();
    final date = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final file = File(p.join(directory.path, '${safeSchool}_enrollment_brief_$date.txt'));
    await file.writeAsString(renderEnrollmentBrief(schoolName: schoolName, date: now, enrollment: enrollment), flush: true);
    return file.path;
  }
}

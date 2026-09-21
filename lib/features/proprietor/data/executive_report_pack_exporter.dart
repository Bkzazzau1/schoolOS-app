import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'owner_reports.dart';

/// Saves the executive report pack (the real reports, as text) on the device.
class ExecutiveReportPackExporter {
  const ExecutiveReportPackExporter();

  Future<String> export({required String schoolName, required OwnerReports reports}) async {
    final directory = await getApplicationDocumentsDirectory();
    final safeSchool = schoolName
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '')
        .toLowerCase();
    final now = reports.generatedOn;
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final file = File(p.join(directory.path, '${safeSchool}_executive_report_pack_$date.txt'));
    await file.writeAsString(renderReportPack(schoolName: schoolName, reports: reports), flush: true);
    return file.path;
  }
}

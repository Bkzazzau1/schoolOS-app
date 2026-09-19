enum AdministratorAttendanceEventStatus {
  checkedIn('Checked in'),
  late('Late'),
  checkedOut('Checked out'),
  unknownScan('Unknown scan'),
  offlineSynced('Offline synced');

  const AdministratorAttendanceEventStatus(this.label);
  final String label;

  static AdministratorAttendanceEventStatus fromLabel(String? value) {
    return values.firstWhere(
      (item) => item.label == value,
      orElse: () => AdministratorAttendanceEventStatus.checkedIn,
    );
  }
}

enum AdministratorAttendanceDeviceStatus {
  online('Online'),
  offline('Offline'),
  syncing('Syncing');

  const AdministratorAttendanceDeviceStatus(this.label);
  final String label;

  static AdministratorAttendanceDeviceStatus fromLabel(String? value) {
    return values.firstWhere(
      (item) => item.label == value,
      orElse: () => AdministratorAttendanceDeviceStatus.offline,
    );
  }
}

class AdministratorAttendanceEvent {
  const AdministratorAttendanceEvent({
    required this.time,
    required this.student,
    required this.className,
    required this.device,
    required this.method,
    required this.status,
    required this.parentState,
  });

  final String time;
  final String student;
  final String className;
  final String device;
  final String method;
  final AdministratorAttendanceEventStatus status;
  final String parentState;

  String get entityId => '$time-$student';

  Map<String, Object?> toJson() => {
        'time': time,
        'student': student,
        'className': className,
        'device': device,
        'method': method,
        'status': status.label,
        'parentState': parentState,
      };

  factory AdministratorAttendanceEvent.fromJson(Map<String, Object?> json) {
    return AdministratorAttendanceEvent(
      time: json['time'] as String? ?? '',
      student: json['student'] as String? ?? '',
      className: json['className'] as String? ?? '',
      device: json['device'] as String? ?? '',
      method: json['method'] as String? ?? '',
      status: AdministratorAttendanceEventStatus.fromLabel(json['status'] as String?),
      parentState: json['parentState'] as String? ?? '',
    );
  }
}

class AdministratorAttendanceDevice {
  const AdministratorAttendanceDevice({
    required this.name,
    required this.location,
    required this.type,
    required this.status,
    required this.lastEvent,
    required this.events,
  });

  final String name;
  final String location;
  final String type;
  final AdministratorAttendanceDeviceStatus status;
  final String lastEvent;
  final String events;

  Map<String, Object?> toJson() => {
        'name': name,
        'location': location,
        'type': type,
        'status': status.label,
        'lastEvent': lastEvent,
        'events': events,
      };

  factory AdministratorAttendanceDevice.fromJson(Map<String, Object?> json) {
    return AdministratorAttendanceDevice(
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      type: json['type'] as String? ?? '',
      status: AdministratorAttendanceDeviceStatus.fromLabel(json['status'] as String?),
      lastEvent: json['lastEvent'] as String? ?? '',
      events: json['events'] as String? ?? '',
    );
  }
}

class AdministratorAttendanceSection {
  const AdministratorAttendanceSection({
    required this.name,
    required this.rate,
    required this.present,
    required this.late,
    required this.absent,
  });

  final String name;
  final int rate;
  final int present;
  final int late;
  final int absent;
}

class AdministratorAttendanceCorrection {
  const AdministratorAttendanceCorrection({
    required this.id,
    required this.student,
    required this.className,
    required this.requestedChange,
    required this.evidence,
  });

  final String id;
  final String student;
  final String className;
  final String requestedChange;
  final String evidence;

  Map<String, Object?> toJson() => {
        'id': id,
        'student': student,
        'className': className,
        'requestedChange': requestedChange,
        'evidence': evidence,
      };

  factory AdministratorAttendanceCorrection.fromJson(Map<String, Object?> json) {
    return AdministratorAttendanceCorrection(
      id: json['id'] as String? ?? '',
      student: json['student'] as String? ?? '',
      className: json['className'] as String? ?? '',
      requestedChange: json['requestedChange'] as String? ?? '',
      evidence: json['evidence'] as String? ?? '',
    );
  }
}

class AdministratorAttendancePermissions {
  const AdministratorAttendancePermissions({
    required this.canViewControlCenter,
    required this.canReviewCorrections,
  });

  final bool canViewControlCenter;
  final bool canReviewCorrections;
}

const administratorAttendanceIntegrityRule =
    'Hardware events create operational evidence, not accusations. Offline events should synchronize before absence is finalized; unknown scans require human review; corrections retain requester, approver, reason and timestamp. Parent notifications should report arrival/departure facts without inferring why a child was late or absent.';

const administratorAttendanceDeviceBoundary =
    'The website exposes Register device but no provisioning workflow. Native must not invent credentials, trust enrollment or hardware authorization; device registration remains a dedicated authorized setup flow.';

const administratorAttendanceCorrectionBoundary =
    'Review on this page is operational review only. A correction must retain requester, approver, reason, timestamp and evidence in the authoritative audit workflow before the daily ledger is changed.';

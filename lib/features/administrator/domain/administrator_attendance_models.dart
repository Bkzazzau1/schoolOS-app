enum AdministratorAttendanceEventStatus {
  checkedIn('Checked in'),
  late('Late'),
  checkedOut('Checked out'),
  unknownScan('Unknown scan'),
  offlineSynced('Offline synced'),
  excused('Excused');

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
    this.date = '',
    this.note = '',
    this.entityKey = '',
  });

  final String time;
  final String student;
  final String className;
  final String device;
  final String method;
  final AdministratorAttendanceEventStatus status;
  final String parentState;

  /// The school day (yyyy-MM-dd). Empty for the old sample events.
  final String date;

  /// Why this event exists when it was not a scan (a correction, a manual check-in, an identified scan).
  final String note;

  /// The record's storage key, kept when the event is changed so the same record is updated.
  final String entityKey;

  /// A fresh event has no [entityKey] yet, so this derives one from time and
  /// student. It must stay a safe sync id (letters, digits, `. _ : -` only,
  /// matching the server's entityId pattern), so spaces and punctuation in a
  /// student's name are never carried through as-is.
  String get entityId => entityKey.isEmpty ? _slug('$time-$student') : entityKey;

  static String _slug(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^A-Za-z0-9._:\-]'), '');
    return cleaned.isEmpty ? 'event' : cleaned;
  }

  bool get isUnknown => status == AdministratorAttendanceEventStatus.unknownScan;

  /// The student was at school (arrived, late, left again, or arrived while offline).
  bool get countsAsPresent =>
      status == AdministratorAttendanceEventStatus.checkedIn ||
      status == AdministratorAttendanceEventStatus.late ||
      status == AdministratorAttendanceEventStatus.checkedOut ||
      status == AdministratorAttendanceEventStatus.offlineSynced;

  AdministratorAttendanceEvent copyWith({
    String? student,
    String? className,
    AdministratorAttendanceEventStatus? status,
    String? method,
    String? note,
  }) =>
      AdministratorAttendanceEvent(
        time: time,
        student: student ?? this.student,
        className: className ?? this.className,
        device: device,
        method: method ?? this.method,
        status: status ?? this.status,
        parentState: parentState,
        date: date,
        note: note ?? this.note,
        entityKey: entityId,
      );

  Map<String, Object?> toJson() => {
        'time': time,
        'student': student,
        'className': className,
        'device': device,
        'method': method,
        'status': status.label,
        'parentState': parentState,
        'date': date,
        'note': note,
        'entityKey': entityKey,
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
      date: json['date'] as String? ?? '',
      note: json['note'] as String? ?? '',
      entityKey: json['entityKey'] as String? ?? '',
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
    this.status = 'Pending',
    this.decidedBy = '',
    this.decidedAt = '',
    this.decisionNote = '',
  });

  final String id;
  final String student;
  final String className;
  final String requestedChange;
  final String evidence;

  /// Pending, Approved or Declined. A decision keeps who made it, when and why.
  final String status;
  final String decidedBy;
  final String decidedAt;
  final String decisionNote;

  bool get isPending => status == 'Pending';

  /// What the day's record becomes if this is approved: the words after the arrow ("Absent → Present" gives "Present").
  String get target => requestedChange.contains('→') ? requestedChange.split('→').last.trim() : '';

  AdministratorAttendanceCorrection decided({required bool approved, required String by, required String note}) =>
      AdministratorAttendanceCorrection(
        id: id,
        student: student,
        className: className,
        requestedChange: requestedChange,
        evidence: evidence,
        status: approved ? 'Approved' : 'Declined',
        decidedBy: by,
        decidedAt: DateTime.now().toUtc().toIso8601String(),
        decisionNote: note,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'student': student,
        'className': className,
        'requestedChange': requestedChange,
        'evidence': evidence,
        'status': status,
        'decidedBy': decidedBy,
        'decidedAt': decidedAt,
        'decisionNote': decisionNote,
      };

  factory AdministratorAttendanceCorrection.fromJson(Map<String, Object?> json) {
    return AdministratorAttendanceCorrection(
      id: json['id'] as String? ?? '',
      student: json['student'] as String? ?? '',
      className: json['className'] as String? ?? '',
      requestedChange: json['requestedChange'] as String? ?? '',
      evidence: json['evidence'] as String? ?? '',
      status: json['status'] as String? ?? 'Pending',
      decidedBy: json['decidedBy'] as String? ?? '',
      decidedAt: json['decidedAt'] as String? ?? '',
      decisionNote: json['decisionNote'] as String? ?? '',
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
    'Approving a correction records who asked, who approved, the reason and the time in the authoritative audit workflow, and adds the correction to the day without erasing the original scan.';

enum PrincipalAttendanceHealth { strong, watch, needsAttention }

enum PrincipalAttendancePersonType { student, staff }

enum PrincipalAttendanceStaffStatus { present, absent }

enum PrincipalAttendancePunctuality { onTime, late, followUp }

enum PrincipalAttendanceSeverity { high, medium, low }

enum PrincipalBiometricModality { palm, fingerprint }

enum PrincipalScannerTransport { usb, lan, serial }

enum PrincipalScannerStatus { ready, offline, syncPending }

enum PrincipalBiometricMatchStatus { matched, unknown, duplicate }

extension PrincipalAttendanceHealthLabel on PrincipalAttendanceHealth {
  String get label => switch (this) {
        PrincipalAttendanceHealth.strong => 'Strong',
        PrincipalAttendanceHealth.watch => 'Watch',
        PrincipalAttendanceHealth.needsAttention => 'Needs attention',
      };

  static PrincipalAttendanceHealth fromLabel(String value) => switch (value) {
        'Strong' => PrincipalAttendanceHealth.strong,
        'Watch' => PrincipalAttendanceHealth.watch,
        'Needs attention' => PrincipalAttendanceHealth.needsAttention,
        _ => PrincipalAttendanceHealth.watch,
      };
}

extension PrincipalAttendancePunctualityLabel on PrincipalAttendancePunctuality {
  String get label => switch (this) {
        PrincipalAttendancePunctuality.onTime => 'On time',
        PrincipalAttendancePunctuality.late => 'Late',
        PrincipalAttendancePunctuality.followUp => 'Follow-up',
      };
}

extension PrincipalAttendanceSeverityLabel on PrincipalAttendanceSeverity {
  String get label => switch (this) {
        PrincipalAttendanceSeverity.high => 'High',
        PrincipalAttendanceSeverity.medium => 'Medium',
        PrincipalAttendanceSeverity.low => 'Low',
      };
}

extension PrincipalBiometricModalityLabel on PrincipalBiometricModality {
  String get label => switch (this) {
        PrincipalBiometricModality.palm => 'Palm',
        PrincipalBiometricModality.fingerprint => 'Fingerprint',
      };
}

extension PrincipalScannerStatusLabel on PrincipalScannerStatus {
  String get label => switch (this) {
        PrincipalScannerStatus.ready => 'Ready',
        PrincipalScannerStatus.offline => 'Offline',
        PrincipalScannerStatus.syncPending => 'Sync pending',
      };
}

class PrincipalClassAttendance {
  const PrincipalClassAttendance({
    required this.className,
    required this.total,
    required this.present,
    required this.absent,
    required this.late,
    required this.excused,
    required this.rate,
    required this.trend,
    required this.status,
  });

  final String className;
  final int total;
  final int present;
  final int absent;
  final int late;
  final int excused;
  final int rate;
  final double trend;
  final PrincipalAttendanceHealth status;

  Map<String, Object?> toJson() => {
        'className': className,
        'total': total,
        'present': present,
        'absent': absent,
        'late': late,
        'excused': excused,
        'rate': rate,
        'trend': trend,
        'status': status.label,
      };

  factory PrincipalClassAttendance.fromJson(Map<String, Object?> json) => PrincipalClassAttendance(
        className: json['className']! as String,
        total: json['total']! as int,
        present: json['present']! as int,
        absent: json['absent']! as int,
        late: json['late']! as int,
        excused: json['excused']! as int,
        rate: json['rate']! as int,
        trend: (json['trend']! as num).toDouble(),
        status: PrincipalAttendanceHealthLabel.fromLabel(json['status']! as String),
      );
}

class PrincipalStaffAttendance {
  const PrincipalStaffAttendance({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
    required this.checkIn,
    required this.punctuality,
  });

  final String id;
  final String name;
  final String role;
  final PrincipalAttendanceStaffStatus status;
  final String checkIn;
  final PrincipalAttendancePunctuality punctuality;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'status': status.name,
        'checkIn': checkIn,
        'punctuality': punctuality.name,
      };

  factory PrincipalStaffAttendance.fromJson(Map<String, Object?> json) => PrincipalStaffAttendance(
        id: json['id']! as String,
        name: json['name']! as String,
        role: json['role']! as String,
        status: PrincipalAttendanceStaffStatus.values.byName(json['status']! as String),
        checkIn: json['checkIn']! as String,
        punctuality: PrincipalAttendancePunctuality.values.byName(json['punctuality']! as String),
      );
}

class PrincipalAttendanceFollowUp {
  const PrincipalAttendanceFollowUp({
    required this.id,
    required this.person,
    required this.type,
    required this.classOrRole,
    required this.issue,
    required this.count,
    required this.severity,
    this.resolved = false,
    this.resolvedAt,
    this.resolvedByMembershipId,
  });

  final String id;
  final String person;
  final PrincipalAttendancePersonType type;
  final String classOrRole;
  final String issue;
  final String count;
  final PrincipalAttendanceSeverity severity;
  final bool resolved;
  final String? resolvedAt;
  final String? resolvedByMembershipId;

  PrincipalAttendanceFollowUp copyWith({
    bool? resolved,
    String? resolvedAt,
    String? resolvedByMembershipId,
  }) =>
      PrincipalAttendanceFollowUp(
        id: id,
        person: person,
        type: type,
        classOrRole: classOrRole,
        issue: issue,
        count: count,
        severity: severity,
        resolved: resolved ?? this.resolved,
        resolvedAt: resolvedAt ?? this.resolvedAt,
        resolvedByMembershipId: resolvedByMembershipId ?? this.resolvedByMembershipId,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'person': person,
        'type': type.name,
        'classOrRole': classOrRole,
        'issue': issue,
        'count': count,
        'severity': severity.name,
        'resolved': resolved,
        'resolvedAt': resolvedAt,
        'resolvedByMembershipId': resolvedByMembershipId,
      };

  factory PrincipalAttendanceFollowUp.fromJson(Map<String, Object?> json) => PrincipalAttendanceFollowUp(
        id: json['id']! as String,
        person: json['person']! as String,
        type: PrincipalAttendancePersonType.values.byName(json['type']! as String),
        classOrRole: json['classOrRole']! as String,
        issue: json['issue']! as String,
        count: json['count']! as String,
        severity: PrincipalAttendanceSeverity.values.byName(json['severity']! as String),
        resolved: json['resolved'] as bool? ?? false,
        resolvedAt: json['resolvedAt'] as String?,
        resolvedByMembershipId: json['resolvedByMembershipId'] as String?,
      );
}

class PrincipalAttendanceTrendPoint {
  const PrincipalAttendanceTrendPoint({required this.day, required this.rate});
  final String day;
  final int rate;
}

class PrincipalBiometricScanner {
  const PrincipalBiometricScanner({
    required this.id,
    required this.name,
    required this.location,
    required this.modality,
    required this.transport,
    required this.status,
    required this.enrolledTemplates,
    required this.pendingEvents,
    required this.lastEventAt,
  });

  final String id;
  final String name;
  final String location;
  final PrincipalBiometricModality modality;
  final PrincipalScannerTransport transport;
  final PrincipalScannerStatus status;
  final int enrolledTemplates;
  final int pendingEvents;
  final String lastEventAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'modality': modality.name,
        'transport': transport.name,
        'status': status.name,
        'enrolledTemplates': enrolledTemplates,
        'pendingEvents': pendingEvents,
        'lastEventAt': lastEventAt,
      };

  factory PrincipalBiometricScanner.fromJson(Map<String, Object?> json) => PrincipalBiometricScanner(
        id: json['id']! as String,
        name: json['name']! as String,
        location: json['location']! as String,
        modality: PrincipalBiometricModality.values.byName(json['modality']! as String),
        transport: PrincipalScannerTransport.values.byName(json['transport']! as String),
        status: PrincipalScannerStatus.values.byName(json['status']! as String),
        enrolledTemplates: json['enrolledTemplates']! as int,
        pendingEvents: json['pendingEvents']! as int,
        lastEventAt: json['lastEventAt']! as String,
      );
}

class PrincipalBiometricAttendanceEvent {
  const PrincipalBiometricAttendanceEvent({
    required this.id,
    required this.personReference,
    required this.personType,
    required this.classOrRole,
    required this.scannerId,
    required this.modality,
    required this.capturedAt,
    required this.localSequence,
    required this.templateReference,
    required this.matchScore,
    required this.matchStatus,
    required this.synced,
  });

  final String id;
  final String personReference;
  final PrincipalAttendancePersonType personType;
  final String classOrRole;
  final String scannerId;
  final PrincipalBiometricModality modality;
  final String capturedAt;
  final int localSequence;
  final String templateReference;
  final double matchScore;
  final PrincipalBiometricMatchStatus matchStatus;
  final bool synced;

  Map<String, Object?> toJson() => {
        'id': id,
        'personReference': personReference,
        'personType': personType.name,
        'classOrRole': classOrRole,
        'scannerId': scannerId,
        'modality': modality.name,
        'capturedAt': capturedAt,
        'localSequence': localSequence,
        'templateReference': templateReference,
        'matchScore': matchScore,
        'matchStatus': matchStatus.name,
        'synced': synced,
      };

  factory PrincipalBiometricAttendanceEvent.fromJson(Map<String, Object?> json) => PrincipalBiometricAttendanceEvent(
        id: json['id']! as String,
        personReference: json['personReference']! as String,
        personType: PrincipalAttendancePersonType.values.byName(json['personType']! as String),
        classOrRole: json['classOrRole']! as String,
        scannerId: json['scannerId']! as String,
        modality: PrincipalBiometricModality.values.byName(json['modality']! as String),
        capturedAt: json['capturedAt']! as String,
        localSequence: json['localSequence']! as int,
        templateReference: json['templateReference']! as String,
        matchScore: (json['matchScore']! as num).toDouble(),
        matchStatus: PrincipalBiometricMatchStatus.values.byName(json['matchStatus']! as String),
        synced: json['synced'] as bool? ?? false,
      );
}

class PrincipalAttendancePermissions {
  const PrincipalAttendancePermissions({
    required this.canViewSecondaryAttendance,
    required this.canResolveFollowUps,
    required this.canIngestOfflineBiometricEvents,
    required this.canManagePrimary,
  });

  final bool canViewSecondaryAttendance;
  final bool canResolveFollowUps;
  final bool canIngestOfflineBiometricEvents;
  final bool canManagePrimary;
}

const principalAttendanceOfflineRule =
    'Attendance capture must continue with zero internet dependency. Palm/fingerprint matching, duplicate checks, event timestamps and local storage happen on the device or local SchoolOS node; sync is deferred until connectivity returns.';

const principalAttendanceBiometricPrivacyRule =
    'Store protected biometric templates or opaque template references, not reusable raw fingerprint/palm images. Biometric data is identity evidence for attendance only and must not be reused for unrelated profiling.';

const principalAttendanceIntegrityRule =
    'A biometric scan creates evidence, not an accusation. Unknown or conflicting matches require human review; absence should not be finalized while a scanner still has unsynchronized attendance events.';

const principalAttendanceScopeBoundary =
    'Principal attendance authority is limited to the active Secondary section. Primary and Early Years attendance remain under their own leadership scopes.';

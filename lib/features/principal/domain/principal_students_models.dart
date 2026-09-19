enum PrincipalStudentRisk { strong, stable, watch, atRisk }

enum PrincipalStudentBehaviour { excellent, good, needsAttention }

enum PrincipalStudentEnrollmentStatus { active, transferPending, withdrawn, alumni }

extension PrincipalStudentRiskLabel on PrincipalStudentRisk {
  String get label => switch (this) {
        PrincipalStudentRisk.strong => 'Strong',
        PrincipalStudentRisk.stable => 'Stable',
        PrincipalStudentRisk.watch => 'Watch',
        PrincipalStudentRisk.atRisk => 'At risk',
      };

  static PrincipalStudentRisk fromLabel(String value) => switch (value) {
        'Strong' => PrincipalStudentRisk.strong,
        'Stable' => PrincipalStudentRisk.stable,
        'Watch' => PrincipalStudentRisk.watch,
        'At risk' => PrincipalStudentRisk.atRisk,
        _ => PrincipalStudentRisk.stable,
      };
}

extension PrincipalStudentBehaviourLabel on PrincipalStudentBehaviour {
  String get label => switch (this) {
        PrincipalStudentBehaviour.excellent => 'Excellent',
        PrincipalStudentBehaviour.good => 'Good',
        PrincipalStudentBehaviour.needsAttention => 'Needs attention',
      };

  static PrincipalStudentBehaviour fromLabel(String value) => switch (value) {
        'Excellent' => PrincipalStudentBehaviour.excellent,
        'Needs attention' => PrincipalStudentBehaviour.needsAttention,
        _ => PrincipalStudentBehaviour.good,
      };
}

class PrincipalStudentSummary {
  const PrincipalStudentSummary({
    required this.id,
    required this.name,
    required this.className,
    required this.average,
    required this.attendance,
    required this.trend,
    required this.behaviour,
    required this.risk,
    required this.incidents,
    required this.interventions,
    required this.guardian,
    required this.concern,
  });

  final String id;
  final String name;
  final String className;
  final int average;
  final int attendance;
  final double trend;
  final PrincipalStudentBehaviour behaviour;
  final PrincipalStudentRisk risk;
  final int incidents;
  final int interventions;
  final String guardian;
  final String concern;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'className': className,
        'average': average,
        'attendance': attendance,
        'trend': trend,
        'behaviour': behaviour.label,
        'risk': risk.label,
        'incidents': incidents,
        'interventions': interventions,
        'guardian': guardian,
        'concern': concern,
      };

  factory PrincipalStudentSummary.fromJson(Map<String, Object?> json) => PrincipalStudentSummary(
        id: json['id']! as String,
        name: json['name']! as String,
        className: json['className']! as String,
        average: json['average']! as int,
        attendance: json['attendance']! as int,
        trend: (json['trend']! as num).toDouble(),
        behaviour: PrincipalStudentBehaviourLabel.fromLabel(json['behaviour']! as String),
        risk: PrincipalStudentRiskLabel.fromLabel(json['risk']! as String),
        incidents: json['incidents']! as int,
        interventions: json['interventions']! as int,
        guardian: json['guardian']! as String,
        concern: json['concern']! as String,
      );
}

class PrincipalStudentSubject {
  const PrincipalStudentSubject({required this.name, required this.score, required this.trend});
  final String name;
  final int score;
  final String trend;
  Map<String, Object?> toJson() => {'name': name, 'score': score, 'trend': trend};
  factory PrincipalStudentSubject.fromJson(Map<String, Object?> json) => PrincipalStudentSubject(
        name: json['name']! as String,
        score: json['score']! as int,
        trend: json['trend']! as String,
      );
}

class PrincipalStudentLabelValue {
  const PrincipalStudentLabelValue({required this.label, required this.value});
  final String label;
  final String value;
  Map<String, Object?> toJson() => {'label': label, 'value': value};
  factory PrincipalStudentLabelValue.fromJson(Map<String, Object?> json) => PrincipalStudentLabelValue(
        label: json['label']! as String,
        value: json['value']! as String,
      );
}

class PrincipalStudentHistoryRow {
  const PrincipalStudentHistoryRow({required this.session, required this.className, required this.outcome, required this.note});
  final String session;
  final String className;
  final String outcome;
  final String note;
  Map<String, Object?> toJson() => {'session': session, 'className': className, 'outcome': outcome, 'note': note};
  factory PrincipalStudentHistoryRow.fromJson(Map<String, Object?> json) => PrincipalStudentHistoryRow(
        session: json['session']! as String,
        className: json['className']! as String,
        outcome: json['outcome']! as String,
        note: json['note']! as String,
      );
}

class PrincipalStudentDocument {
  const PrincipalStudentDocument({required this.name, required this.status, required this.visibility});
  final String name;
  final String status;
  final String visibility;
  Map<String, Object?> toJson() => {'name': name, 'status': status, 'visibility': visibility};
  factory PrincipalStudentDocument.fromJson(Map<String, Object?> json) => PrincipalStudentDocument(
        name: json['name']! as String,
        status: json['status']! as String,
        visibility: json['visibility']! as String,
      );
}

class PrincipalStudentTimelineItem {
  const PrincipalStudentTimelineItem({required this.date, required this.title, required this.detail, required this.visibility});
  final String date;
  final String title;
  final String detail;
  final String visibility;
  Map<String, Object?> toJson() => {'date': date, 'title': title, 'detail': detail, 'visibility': visibility};
  factory PrincipalStudentTimelineItem.fromJson(Map<String, Object?> json) => PrincipalStudentTimelineItem(
        date: json['date']! as String,
        title: json['title']! as String,
        detail: json['detail']! as String,
        visibility: json['visibility']! as String,
      );
}

class PrincipalStudentProfile {
  const PrincipalStudentProfile({
    required this.summary,
    required this.admissionNo,
    required this.campus,
    required this.enrollmentStatus,
    required this.classTeacher,
    required this.guardianPhone,
    required this.familyAccountId,
    required this.admissionDate,
    required this.dateOfBirth,
    required this.gender,
    required this.house,
    required this.medicalInstruction,
    required this.healthRecordLabel,
    required this.transport,
    required this.meals,
    required this.boarding,
    required this.feeVisibility,
    required this.previousSchool,
    required this.activities,
    required this.awards,
    required this.subjects,
    required this.attendanceSummary,
    required this.promotionHistory,
    required this.documents,
    required this.timeline,
  });

  final PrincipalStudentSummary summary;
  final String admissionNo;
  final String campus;
  final PrincipalStudentEnrollmentStatus enrollmentStatus;
  final String classTeacher;
  final String guardianPhone;
  final String familyAccountId;
  final String admissionDate;
  final String dateOfBirth;
  final String gender;
  final String house;
  final String medicalInstruction;
  final String healthRecordLabel;
  final String transport;
  final String meals;
  final String boarding;
  final String feeVisibility;
  final String previousSchool;
  final List<String> activities;
  final List<String> awards;
  final List<PrincipalStudentSubject> subjects;
  final List<PrincipalStudentLabelValue> attendanceSummary;
  final List<PrincipalStudentHistoryRow> promotionHistory;
  final List<PrincipalStudentDocument> documents;
  final List<PrincipalStudentTimelineItem> timeline;

  Map<String, Object?> toJson() => {
        'summary': summary.toJson(),
        'admissionNo': admissionNo,
        'campus': campus,
        'enrollmentStatus': enrollmentStatus.name,
        'classTeacher': classTeacher,
        'guardianPhone': guardianPhone,
        'familyAccountId': familyAccountId,
        'admissionDate': admissionDate,
        'dateOfBirth': dateOfBirth,
        'gender': gender,
        'house': house,
        'medicalInstruction': medicalInstruction,
        'healthRecordLabel': healthRecordLabel,
        'transport': transport,
        'meals': meals,
        'boarding': boarding,
        'feeVisibility': feeVisibility,
        'previousSchool': previousSchool,
        'activities': activities,
        'awards': awards,
        'subjects': subjects.map((e) => e.toJson()).toList(),
        'attendanceSummary': attendanceSummary.map((e) => e.toJson()).toList(),
        'promotionHistory': promotionHistory.map((e) => e.toJson()).toList(),
        'documents': documents.map((e) => e.toJson()).toList(),
        'timeline': timeline.map((e) => e.toJson()).toList(),
      };

  factory PrincipalStudentProfile.fromJson(Map<String, Object?> json) => PrincipalStudentProfile(
        summary: PrincipalStudentSummary.fromJson((json['summary']! as Map).cast<String, Object?>()),
        admissionNo: json['admissionNo']! as String,
        campus: json['campus']! as String,
        enrollmentStatus: PrincipalStudentEnrollmentStatus.values.byName(json['enrollmentStatus']! as String),
        classTeacher: json['classTeacher']! as String,
        guardianPhone: json['guardianPhone']! as String,
        familyAccountId: json['familyAccountId']! as String,
        admissionDate: json['admissionDate']! as String,
        dateOfBirth: json['dateOfBirth']! as String,
        gender: json['gender']! as String,
        house: json['house']! as String,
        medicalInstruction: json['medicalInstruction']! as String,
        healthRecordLabel: json['healthRecordLabel']! as String,
        transport: json['transport']! as String,
        meals: json['meals']! as String,
        boarding: json['boarding']! as String,
        feeVisibility: json['feeVisibility']! as String,
        previousSchool: json['previousSchool']! as String,
        activities: (json['activities']! as List).cast<String>(),
        awards: (json['awards']! as List).cast<String>(),
        subjects: (json['subjects']! as List).map((e) => PrincipalStudentSubject.fromJson((e as Map).cast<String, Object?>())).toList(),
        attendanceSummary: (json['attendanceSummary']! as List).map((e) => PrincipalStudentLabelValue.fromJson((e as Map).cast<String, Object?>())).toList(),
        promotionHistory: (json['promotionHistory']! as List).map((e) => PrincipalStudentHistoryRow.fromJson((e as Map).cast<String, Object?>())).toList(),
        documents: (json['documents']! as List).map((e) => PrincipalStudentDocument.fromJson((e as Map).cast<String, Object?>())).toList(),
        timeline: (json['timeline']! as List).map((e) => PrincipalStudentTimelineItem.fromJson((e as Map).cast<String, Object?>())).toList(),
      );
}

class PrincipalStudentLifecycleProposal {
  const PrincipalStudentLifecycleProposal({
    required this.id,
    required this.studentId,
    required this.actionType,
    required this.nextClassOrDestination,
    required this.effectiveSession,
    required this.reason,
    required this.requestedByMembershipId,
    required this.requestedAt,
  });
  final String id;
  final String studentId;
  final String actionType;
  final String nextClassOrDestination;
  final String effectiveSession;
  final String reason;
  final String requestedByMembershipId;
  final String requestedAt;
  Map<String, Object?> toJson() => {
        'id': id,
        'studentId': studentId,
        'actionType': actionType,
        'nextClassOrDestination': nextClassOrDestination,
        'effectiveSession': effectiveSession,
        'reason': reason,
        'requestedByMembershipId': requestedByMembershipId,
        'requestedAt': requestedAt,
        'status': 'Pending governed execution',
      };
}

class PrincipalStudentPermissions {
  const PrincipalStudentPermissions({
    required this.canViewSecondaryStudents,
    required this.canAddLeadershipNote,
    required this.canCreateLifecycleProposal,
    required this.canManagePrimary,
    required this.canViewConfidentialFinance,
  });
  final bool canViewSecondaryStudents;
  final bool canAddLeadershipNote;
  final bool canCreateLifecycleProposal;
  final bool canManagePrimary;
  final bool canViewConfidentialFinance;
}

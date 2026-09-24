import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/domain/administrator_students_models.dart';

class AssignedCurriculumTopic {
  const AssignedCurriculumTopic({
    required this.id,
    required this.sequence,
    required this.title,
    required this.description,
  });

  final String id;
  final int sequence;
  final String title;
  final String description;

  factory AssignedCurriculumTopic.fromJson(Map<String, Object?> json) =>
      AssignedCurriculumTopic(
        id: json['id'] as String? ?? '',
        sequence: json['sequence'] as int? ?? 1,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'sequence': sequence,
        'title': title,
        'description': description,
      };
}

/// A class-subject responsibility assigned to this Teacher membership.
class AssignedClass {
  const AssignedClass({
    required this.className,
    required this.subject,
    this.room = '',
    this.time = '',
    this.sessionId = '',
    this.classId = '',
    this.subjectId = '',
    this.classSubjectId = '',
    this.teachingAssignmentId = '',
    this.periodsPerWeek = 0,
    this.currentTermId = '',
    this.currentTerm = '',
    this.topics = const [],
  });

  final String className;
  final String subject;
  final String room;
  final String time;
  final String sessionId;
  final String classId;
  final String subjectId;
  final String classSubjectId;
  final String teachingAssignmentId;
  final int periodsPerWeek;
  final String currentTermId;
  final String currentTerm;
  final List<AssignedCurriculumTopic> topics;

  Map<String, Object?> toJson() => {
        'className': className,
        'subject': subject,
        'room': room,
        'time': time,
        'sessionId': sessionId,
        'classId': classId,
        'subjectId': subjectId,
        'classSubjectId': classSubjectId,
        'teachingAssignmentId': teachingAssignmentId,
        'periodsPerWeek': periodsPerWeek,
        'currentTermId': currentTermId,
        'currentTerm': currentTerm,
        'topics': [for (final item in topics) item.toJson()],
      };

  factory AssignedClass.fromJson(Map<String, Object?> json) => AssignedClass(
        className: json['className'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        room: json['room'] as String? ?? '',
        time: json['time'] as String? ?? '',
        sessionId: json['sessionId'] as String? ?? '',
        classId: json['classId'] as String? ?? '',
        subjectId: json['subjectId'] as String? ?? '',
        classSubjectId: json['classSubjectId'] as String? ?? '',
        teachingAssignmentId: json['teachingAssignmentId'] as String? ?? '',
        periodsPerWeek: json['periodsPerWeek'] as int? ?? 0,
        currentTermId: json['currentTermId'] as String? ?? '',
        currentTerm: json['currentTerm'] as String? ?? '',
        topics: [
          for (final item in (json['topics'] as List? ?? const []))
            if (item is Map)
              AssignedCurriculumTopic.fromJson(
                Map<String, Object?>.from(item),
              ),
        ],
      );
}

/// Which classes each standalone demo teacher teaches. Server-backed schools
/// receive a private server-generated teacher_class_assignment record instead.
const _demoAssignments = <String, List<AssignedClass>>{
  'membership-teacher-002': [
    AssignedClass(
      className: 'Primary 3',
      subject: 'Class teacher',
      room: 'P3',
      time: '8:00',
    ),
    AssignedClass(
      className: 'Primary 4',
      subject: 'English',
      room: 'P4',
      time: '9:20',
    ),
  ],
  'membership-teacher-003': [
    AssignedClass(
      className: 'JSS 2A',
      subject: 'Mathematics',
      room: 'B12',
      time: '8:00',
    ),
    AssignedClass(
      className: 'JSS 2B',
      subject: 'Mathematics',
      room: 'B14',
      time: '9:20',
    ),
  ],
};

class TeacherRoster {
  TeacherRoster({
    required this.database,
    required this.session,
    required this.students,
  });

  final LocalDatabase database;
  final SchoolSessionController session;
  final AdministratorStudentsRepository students;

  static const assignmentType = 'teacher_class_assignment';

  Future<List<AssignedClass>> assignedClasses([SchoolMembership? who]) async {
    final membership = who ?? session.requireActiveMembership();
    var record = await database.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: assignmentType,
      entityId: membership.id,
    );
    if (record == null && !LocalDatabase.blockDemoSeeds) {
      final demo = _demoAssignments[membership.id];
      if (demo != null) {
        await database.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: assignmentType,
          entityId: membership.id,
          payload: {
            'teacherMembershipId': membership.id,
            'classes': [for (final item in demo) item.toJson()],
          },
        );
        record = await database.getLocalRecord(
          tenantId: membership.schoolId,
          entityType: assignmentType,
          entityId: membership.id,
        );
      }
    }
    return [
      for (final item in (record?.payload['classes'] as List? ?? const []))
        if (item is Map)
          AssignedClass.fromJson(Map<String, Object?>.from(item)),
    ];
  }

  /// Class assignment is now server-authoritative. Principals use Teaching
  /// Assignments, which validates the curriculum and Teacher membership before
  /// the private teacher link is published.
  Future<String?> assign(
    SchoolMembership teacher,
    List<AssignedClass> classes,
  ) async =>
      'Teacher class assignments are server-controlled. Use the Principal Teaching Assignments workspace.';

  Future<List<AdministratorStudentRecord>> studentsIn(String className) async {
    final all = (await students.load()).students;
    final wanted = className.trim().toLowerCase();
    return [
      for (final student in all)
        if (student.status == AdministratorStudentStatus.active &&
            student.className.trim().toLowerCase() == wanted)
          student,
    ]..sort((a, b) => a.name.compareTo(b.name));
  }
}

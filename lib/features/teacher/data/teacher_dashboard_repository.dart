import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../domain/teacher_attendance_models.dart';
import '../domain/teacher_cbt_models.dart';
import '../domain/teacher_dashboard_models.dart';
import '../domain/teacher_lesson_plan_models.dart';
import '../domain/teacher_performance_models.dart';
import '../domain/teacher_timetable_models.dart';
import '../domain/teacher_weekly_learning_models.dart';
import 'teacher_attendance_repository.dart';
import 'teacher_cbt_repository.dart';
import 'teacher_classes_repository.dart';
import 'teacher_learning_progress_repository.dart';
import 'teacher_lesson_plan_repository.dart';
import 'teacher_performance_repository.dart';
import 'teacher_profile_repository.dart';
import 'teacher_roster.dart';
import 'teacher_syllabus_repository.dart';
import 'teacher_timetable_repository.dart';
import 'teacher_weekly_learning_repository.dart';

class TeacherDashboardSnapshot {
  const TeacherDashboardSnapshot({
    required this.displayName,
    required this.kpis,
    required this.classes,
    required this.todaySchedule,
    required this.students,
    required this.tasks,
    required this.lessonPlansSubmitted,
    required this.lessonPlansTotal,
    required this.weeklyUpdateReady,
    required this.cbtPublished,
    required this.performanceScore,
    required this.performanceLabel,
    required this.performanceMetrics,
  });

  final String displayName;
  final List<TeacherKpi> kpis;
  final List<TeacherClassSummary> classes;
  final List<TeacherScheduleItem> todaySchedule;
  final List<TeacherStudentReview> students;
  final List<TeacherTask> tasks;
  final int lessonPlansSubmitted;
  final int lessonPlansTotal;
  final bool weeklyUpdateReady;
  final int cbtPublished;
  final int performanceScore;
  final String performanceLabel;
  final List<TeacherPerformanceMetric> performanceMetrics;
}

abstract interface class TeacherDashboardDataSource {
  Future<TeacherDashboardSnapshot> load();
}

const _dayNames = {
  1: 'Monday',
  2: 'Tuesday',
  3: 'Wednesday',
  4: 'Thursday',
  5: 'Friday',
  6: 'Saturday',
  7: 'Sunday',
};

/// Every figure here is read from the same real repositories every other Teacher screen already
/// produces (classes, timetable, attendance, lesson plans, weekly learning, CBT, syllabus,
/// performance) - no fixed identity, schedule, class roster, student list or AI narrative is ever
/// shown in its place.
class TeacherDashboardRepository implements TeacherDashboardDataSource {
  TeacherDashboardRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required TeacherRoster roster,
  })  : _schoolSession = schoolSession,
        _roster = roster,
        _profile = TeacherProfileRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
          roster: roster,
        ),
        _classes = TeacherClassesRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
          roster: roster,
        ),
        _timetable = TeacherTimetableRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
          roster: roster,
        ),
        _attendance = TeacherAttendanceRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
          roster: roster,
        ),
        _lessonPlans = TeacherLessonPlanRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
          roster: roster,
        ),
        _weeklyLearning = TeacherWeeklyLearningRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        ),
        _cbt = TeacherCbtRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
          roster: roster,
        ),
        _syllabus = TeacherSyllabusRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
          roster: roster,
        ),
        _learningProgress = TeacherLearningProgressRepository(
          schoolSession: schoolSession,
          roster: roster,
        ),
        _performance = TeacherPerformanceRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
          roster: roster,
        );

  final SchoolSessionController _schoolSession;
  final TeacherRoster _roster;
  final TeacherProfileRepository _profile;
  final TeacherClassesRepository _classes;
  final TeacherTimetableRepository _timetable;
  final TeacherAttendanceRepository _attendance;
  final TeacherLessonPlanRepository _lessonPlans;
  final TeacherWeeklyLearningRepository _weeklyLearning;
  final TeacherCbtRepository _cbt;
  final TeacherSyllabusRepository _syllabus;
  final TeacherLearningProgressRepository _learningProgress;
  final TeacherPerformanceRepository _performance;

  @override
  Future<TeacherDashboardSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final today = _dayNames[DateTime.now().weekday] ?? '';

    final profileSnapshot = await _profile.load();
    final classesSnapshot = await _classes.load();
    final timetableSnapshot = await _timetable.load();
    final attendanceSnapshot = await _attendance.load();
    final lessonPlanSnapshot = await _lessonPlans.load();
    final weeklyLearningSnapshot = await _weeklyLearning.load();
    final cbtSnapshot = await _cbt.load();
    final syllabusSnapshot = await _syllabus.load();
    final learningProgressSnapshot = await _learningProgress.load();
    final performanceSnapshot = await _performance.load();

    final assignedNames = {for (final c in await _roster.assignedClasses(membership)) c.className};

    final syllabusPaceByClass = {
      for (final name in assignedNames) name: syllabusSnapshot.coverageOf(name),
    };

    final classes = [
      for (final assignment in classesSnapshot.assignments)
        TeacherClassSummary(
          name: assignment.name,
          subject: assignment.subject,
          students: assignment.students,
          nextLesson: assignment.nextLesson.isEmpty ? 'Not scheduled' : assignment.nextLesson,
          room: assignment.room,
          progress: syllabusPaceByClass[assignment.name] ?? 0,
        ),
    ];

    final todaySchedule = [
      for (final lesson in timetableSnapshot.lessons)
        if (lesson.day == today)
          TeacherScheduleItem(
            time: lesson.time,
            className: lesson.className,
            topic: lesson.topic.isEmpty ? lesson.subject : lesson.topic,
            status: _lessonStatusLabel(lesson.status),
          ),
    ]..sort((a, b) => a.time.compareTo(b.time));

    final students = [
      for (final student in learningProgressSnapshot.students)
        TeacherStudentReview(name: student.name, className: student.className),
    ];

    final totalStudents = {for (final s in learningProgressSnapshot.students) s.id}.length;

    final avgSyllabusPace = syllabusPaceByClass.isEmpty
        ? 0
        : (syllabusPaceByClass.values.reduce((a, b) => a + b) / syllabusPaceByClass.length).round();

    final kpis = [
      TeacherKpi(
        label: "Today's lessons",
        value: '${todaySchedule.length}',
        hint: today.isEmpty ? 'No real timetable day found' : 'Scheduled for $today',
      ),
      TeacherKpi(
        label: 'My students',
        value: '$totalStudents',
        hint: 'Across ${assignedNames.length} assigned class${assignedNames.length == 1 ? '' : 'es'}',
      ),
      TeacherKpi(
        label: 'Classes assigned',
        value: '${assignedNames.length}',
        hint: assignedNames.isEmpty ? 'No real assignment yet' : assignedNames.join(', '),
      ),
      TeacherKpi(
        label: 'Syllabus progress',
        value: '$avgSyllabusPace%',
        hint: 'Average topic coverage across assigned classes',
      ),
    ];

    final relevantPlans =
        lessonPlanSnapshot.plans.where((p) => assignedNames.contains(p.className)).toList();
    final advancedPlans =
        relevantPlans.where((p) => p.status != TeacherLessonPlanStatus.draft).length;

    final relevantUpdates = weeklyLearningSnapshot.updates
        .where((u) => assignedNames.contains(u.className))
        .toList();
    final weeklyUpdateReady = relevantUpdates.any(
      (u) =>
          u.state == TeacherWeeklyPublicationState.queuedForPublication ||
          u.state == TeacherWeeklyPublicationState.published,
    );

    final cbtPublished =
        cbtSnapshot.tests.where((t) => t.state == TeacherCbtTestState.published).length;

    final submittedRegisters = attendanceSnapshot.registers
        .where((r) => r.submissionState != TeacherAttendanceSubmissionState.draft)
        .length;

    final tasks = <TeacherTask>[
      if (attendanceSnapshot.registers.isNotEmpty &&
          submittedRegisters < attendanceSnapshot.registers.length)
        TeacherTask(
          title: 'Submit attendance',
          meta:
              '$submittedRegisters of ${attendanceSnapshot.registers.length} real registers submitted',
          tone: 'warn',
          destination: 'attendance',
        ),
      if (relevantPlans.isNotEmpty && advancedPlans < relevantPlans.length)
        TeacherTask(
          title: 'Finish lesson plan drafts',
          meta: '$advancedPlans of ${relevantPlans.length} real plans submitted or further along',
          tone: 'normal',
          destination: 'lesson-plans',
        ),
      if (relevantUpdates.isNotEmpty && !weeklyUpdateReady)
        const TeacherTask(
          title: 'Publish weekly learning update',
          meta: 'A real weekly update is still in draft',
          tone: 'warn',
          destination: 'weekly-progress',
        ),
    ];

    return TeacherDashboardSnapshot(
      displayName: profileSnapshot.profile.displayName,
      kpis: kpis,
      classes: classes,
      todaySchedule: todaySchedule,
      students: students,
      tasks: tasks,
      lessonPlansSubmitted: advancedPlans,
      lessonPlansTotal: relevantPlans.length,
      weeklyUpdateReady: weeklyUpdateReady,
      cbtPublished: cbtPublished,
      performanceScore: performanceSnapshot.overallScore,
      performanceLabel: performanceSnapshot.scoreLabel,
      performanceMetrics: performanceSnapshot.metrics,
    );
  }

  String _lessonStatusLabel(TeacherTimetableLessonStatus status) => switch (status) {
        TeacherTimetableLessonStatus.scheduled => 'Scheduled',
        TeacherTimetableLessonStatus.substitution => 'Substitution',
        TeacherTimetableLessonStatus.uncovered => 'Uncovered',
        TeacherTimetableLessonStatus.clash => 'Clash',
        TeacherTimetableLessonStatus.cancelled => 'Cancelled',
      };
}

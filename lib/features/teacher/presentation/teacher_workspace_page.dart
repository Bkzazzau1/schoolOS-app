import '../../../core/appearance/school_logo.dart';
import '../../notifications/presentation/notifications_bell.dart';
import '../../../core/sync/sync_scope.dart';
import 'package:flutter/material.dart';

import '../../../core/appearance/school_appearance_controller.dart';
import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/presentation/administrator_workspace_page.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../finance_office/presentation/finance_office_workspace_page.dart';
import '../../principal/presentation/principal_workspace_page.dart';
import '../../proprietor/presentation/proprietor_workspace_page.dart';
import '../../sync_center/presentation/sync_center_page.dart';
import '../../administrator/data/administrator_students_repository.dart';
import '../data/teacher_ai_repository.dart';
import '../data/teacher_roster.dart';
import '../data/teacher_assignment_repository.dart';
import '../data/teacher_assessment_repository.dart';
import '../data/teacher_attendance_repository.dart';
import '../data/teacher_cbt_repository.dart';
import '../data/teacher_classes_repository.dart';
import '../data/teacher_dashboard_demo_data.dart';
import '../data/teacher_learning_progress_repository.dart';
import '../data/teacher_lesson_plan_repository.dart';
import '../data/teacher_messages_repository.dart';
import '../data/teacher_performance_repository.dart';
import '../data/teacher_profile_repository.dart';
import '../data/teacher_students_repository.dart';
import '../data/teacher_syllabus_repository.dart';
import '../data/teacher_timetable_repository.dart';
import '../data/teacher_weekly_learning_repository.dart';
import '../domain/teacher_dashboard_models.dart';
import 'teacher_ai_page.dart';
import 'teacher_assignments_page.dart';
import 'teacher_assessments_page.dart';
import 'teacher_attendance_page.dart';
import 'teacher_cbt_page.dart';
import 'teacher_classes_page.dart';
import 'teacher_dashboard_page.dart';
import 'teacher_learning_progress_page.dart';
import 'teacher_lesson_plans_page.dart';
import 'teacher_messages_page.dart';
import 'teacher_performance_page.dart';
import 'teacher_profile_page.dart';
import 'teacher_students_page.dart';
import 'teacher_syllabus_page.dart';
import 'teacher_timetable_page.dart';
import 'teacher_weekly_learning_page.dart';

class TeacherWorkspacePage extends StatefulWidget {
  const TeacherWorkspacePage({
    super.key,
    required this.membership,
    required this.localDatabase,
    required this.schoolSession,
    required this.schoolAppearance,
  });

  final SchoolMembership membership;
  final LocalDatabase localDatabase;
  final SchoolSessionController schoolSession;
  final SchoolAppearanceController schoolAppearance;

  @override
  State<TeacherWorkspacePage> createState() => _TeacherWorkspacePageState();
}

class _TeacherWorkspacePageState extends State<TeacherWorkspacePage> with SyncRefresh<TeacherWorkspacePage>, AccessAware<TeacherWorkspacePage> {
  /// The screens the owner allows this person (all of them until their access is known).
  List<TeacherNavItem> get _navigation =>
      visibleScreens('teacher', teacherNavigation, (item) => item.key);

  String _activeKey = 'dashboard';
  int _pendingSyncCount = 0;

  late final TeacherTimetableRepository _timetable;
  late final TeacherClassesRepository _classes;
  late final TeacherRoster _roster;
  late final TeacherAttendanceRepository _attendance;
  late final TeacherLessonPlanRepository _lessonPlans;
  late final TeacherWeeklyLearningRepository _weeklyLearning;
  late final TeacherSyllabusRepository _syllabus;
  late final TeacherAssignmentRepository _assignments;
  late final TeacherAssessmentRepository _assessments;
  late final TeacherCbtRepository _cbt;
  late final TeacherLearningProgressRepository _learningProgress;
  late final TeacherStudentsRepository _students;
  late final TeacherMessagesRepository _messages;
  late final TeacherAiRepository _teacherAi;
  late final TeacherPerformanceRepository _performance;
  late final TeacherProfileRepository _profile;

  TeacherNavItem get _activeItem => _navigation.firstWhere(
        (item) => item.key == _activeKey,
        orElse: () => _navigation.first,
      );

  @override
  void initState() {
    super.initState();
    _timetable = TeacherTimetableRepository(localDatabase: widget.localDatabase, schoolSession: widget.schoolSession);
    _roster = TeacherRoster(
      database: widget.localDatabase,
      session: widget.schoolSession,
      students: AdministratorStudentsRepository(localDatabase: widget.localDatabase, schoolSession: widget.schoolSession),
    );
    _classes = TeacherClassesRepository(localDatabase: widget.localDatabase, schoolSession: widget.schoolSession, roster: _roster);
    _attendance = TeacherAttendanceRepository(localDatabase: widget.localDatabase, schoolSession: widget.schoolSession, roster: _roster);
    _lessonPlans = TeacherLessonPlanRepository(localDatabase: widget.localDatabase, schoolSession: widget.schoolSession);
    _weeklyLearning = TeacherWeeklyLearningRepository(localDatabase: widget.localDatabase, schoolSession: widget.schoolSession);
    _syllabus = TeacherSyllabusRepository(localDatabase: widget.localDatabase, schoolSession: widget.schoolSession, roster: _roster);
    _assignments = TeacherAssignmentRepository(localDatabase: widget.localDatabase, schoolSession: widget.schoolSession);
    _assessments = TeacherAssessmentRepository(localDatabase: widget.localDatabase, schoolSession: widget.schoolSession, roster: _roster);
    _cbt = TeacherCbtRepository(localDatabase: widget.localDatabase, schoolSession: widget.schoolSession, roster: _roster);
    _learningProgress = TeacherLearningProgressRepository(schoolSession: widget.schoolSession, roster: _roster);
    _students = TeacherStudentsRepository(localDatabase: widget.localDatabase, schoolSession: widget.schoolSession, roster: _roster);
    _messages = TeacherMessagesRepository(localDatabase: widget.localDatabase, schoolSession: widget.schoolSession);
    _teacherAi = TeacherAiRepository(localDatabase: widget.localDatabase, schoolSession: widget.schoolSession);
    _performance = TeacherPerformanceRepository(localDatabase: widget.localDatabase, schoolSession: widget.schoolSession);
    _profile = TeacherProfileRepository(localDatabase: widget.localDatabase, schoolSession: widget.schoolSession);
    _refreshPendingCount();
  }

  void _select(String key) {
    if (!_navigation.any((item) => item.key == key)) return;
    setState(() => _activeKey = key);
  }

  @override
  void onSynced() => _refreshPendingCount();

  void _refreshPendingCount() {
    final count = widget.localDatabase.pendingCount(tenantId: widget.membership.schoolId);
    if (mounted) setState(() => _pendingSyncCount = count);
  }

  Future<void> _openSyncCenter() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SyncCenterPage(localDatabase: widget.localDatabase, membership: widget.membership),
      ),
    );
    _refreshPendingCount();
  }

  Future<void> _switchSchool(SchoolMembership membership) async {
    if (membership.id == widget.membership.id) return;
    await widget.schoolSession.selectSchool(membership);
    if (!mounted) return;
    final Widget page = switch (membership.role) {
      SchoolRole.proprietor => ProprietorWorkspacePage(
          membership: membership,
          localDatabase: widget.localDatabase,
          schoolSession: widget.schoolSession,
          schoolAppearance: widget.schoolAppearance,
        ),
      SchoolRole.administrator => AdministratorWorkspacePage(
          membership: membership,
          localDatabase: widget.localDatabase,
          schoolSession: widget.schoolSession,
          schoolAppearance: widget.schoolAppearance,
        ),
      SchoolRole.principal => PrincipalWorkspacePage(
          membership: membership,
          localDatabase: widget.localDatabase,
          schoolSession: widget.schoolSession,
          schoolAppearance: widget.schoolAppearance,
        ),
      SchoolRole.accountant => FinanceOfficeWorkspacePage(
          membership: membership,
          localDatabase: widget.localDatabase,
          schoolSession: widget.schoolSession,
          schoolAppearance: widget.schoolAppearance,
        ),
      SchoolRole.teacher => TeacherWorkspacePage(
          membership: membership,
          localDatabase: widget.localDatabase,
          schoolSession: widget.schoolSession,
          schoolAppearance: widget.schoolAppearance,
        ),
      _ => DashboardPage(
          membership: membership,
          localDatabase: widget.localDatabase,
          schoolSession: widget.schoolSession,
          schoolAppearance: widget.schoolAppearance,
        ),
    };
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => page));
  }

  Widget _content() => switch (_activeKey) {
        'dashboard' => TeacherDashboardPage(schoolName: widget.membership.schoolName, onNavigate: _select),
        'timetable' => TeacherTimetablePage(repository: _timetable, onNavigate: _select, onMutationQueued: _refreshPendingCount),
        'classes' => TeacherClassesPage(schoolName: widget.membership.schoolName, repository: _classes, onNavigate: _select),
        'attendance' => TeacherAttendancePage(repository: _attendance, onNavigate: _select, onMutationQueued: _refreshPendingCount),
        'lesson-plans' => TeacherLessonPlansPage(repository: _lessonPlans, onNavigate: _select, onMutationQueued: _refreshPendingCount),
        'weekly-progress' => TeacherWeeklyLearningPage(repository: _weeklyLearning, onNavigate: _select, onMutationQueued: _refreshPendingCount),
        'syllabus' => TeacherSyllabusPage(repository: _syllabus, onNavigate: _select, onMutationQueued: _refreshPendingCount),
        'assignments' => TeacherAssignmentsPage(repository: _assignments, onNavigate: _select, onMutationQueued: _refreshPendingCount),
        'assessments' => TeacherAssessmentsPage(repository: _assessments, onNavigate: _select, onMutationQueued: _refreshPendingCount),
        'cbt' => TeacherCbtPage(repository: _cbt, onNavigate: _select, onMutationQueued: _refreshPendingCount),
        'learning-progress' => TeacherLearningProgressPage(repository: _learningProgress, onNavigate: _select),
        'students' => TeacherStudentsPage(repository: _students, onNavigate: _select, onMutationQueued: _refreshPendingCount),
        'messages' => TeacherMessagesPage(repository: _messages, onNavigate: _select, onMutationQueued: _refreshPendingCount),
        'ai' => TeacherAiPage(repository: _teacherAi, onNavigate: _select),
        'performance' => TeacherPerformancePage(repository: _performance, onNavigate: _select),
        'profile' => TeacherProfilePage(repository: _profile, onNavigate: _select, onMutationQueued: _refreshPendingCount),
        _ => TeacherDashboardPage(schoolName: widget.membership.schoolName, onNavigate: _select),
      };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 700 ? _phone() : _wide(constraints),
      );

  Widget _phone() => Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.membership.schoolName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              const Text('Teacher Portal', style: TextStyle(fontSize: 12)),
            ],
          ),
          actions: [
            if (widget.schoolSession.canSwitchSchool)
              _SchoolSwitcherButton(memberships: widget.schoolSession.memberships, onSelected: _switchSchool),
            NotificationsBell(membership: widget.membership),
            IconButton(
              tooltip: _pendingSyncCount == 0 ? 'Sync Center' : 'Sync Center · $_pendingSyncCount pending',
              onPressed: _openSyncCenter,
              icon: Badge(
                isLabelVisible: _pendingSyncCount > 0,
                label: Text('$_pendingSyncCount'),
                child: const Icon(Icons.cloud_sync_outlined),
              ),
            ),
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Teacher menu',
                onPressed: () => Scaffold.of(context).openEndDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
          ],
        ),
        endDrawer: Drawer(
          child: SafeArea(
            child: ListView(
              children: [
                const ListTile(title: Text('Teacher Portal', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('Teaching workspace')),
                const Divider(),
                for (final item in _navigation)
                  ListTile(
                    selected: item.key == _activeKey,
                    leading: Icon(_iconFor(item.key)),
                    title: Text(item.label),
                    trailing: item.key == 'ai' ? const Chip(label: Text('AI')) : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      _select(item.key);
                    },
                  ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Text(_activeItem.label, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            Expanded(child: _content()),
          ],
        ),
      );

  Widget _wide(BoxConstraints constraints) {
    final extended = constraints.maxWidth >= 1180;
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child: Container(
              width: extended ? 290 : 88,
              decoration: BoxDecoration(border: Border(right: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: extended
                        ? ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: SchoolLogo(schoolName: widget.membership.schoolName),
                            title: const Text('SchoolOS', style: TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: const Text('Teacher Portal'),
                          )
                        : SchoolLogo(schoolName: widget.membership.schoolName),
                  ),
                  if (extended)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ACTIVE WORKSPACE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Text(widget.membership.schoolName, style: const TextStyle(fontWeight: FontWeight.w900)),
                              const Text(teacherCampusLabel, style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final item in _navigation)
                          ListTile(
                            selected: item.key == _activeKey,
                            selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
                            leading: Icon(_iconFor(item.key)),
                            title: extended ? Text(item.label) : null,
                            trailing: extended && item.key == 'ai' ? const Chip(label: Text('AI')) : null,
                            onTap: () => _select(item.key),
                          ),
                      ],
                    ),
                  ),
                  if (extended)
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Weekly compliance', style: TextStyle(fontSize: 12)),
                          Text('92%', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                          LinearProgressIndicator(value: .92),
                          SizedBox(height: 6),
                          Text('Lesson plans, attendance & scores', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Teacher Workspace', style: TextStyle(fontWeight: FontWeight.w900)),
                              Text(_activeItem.label),
                            ],
                          ),
                        ),
                        if (widget.schoolSession.canSwitchSchool)
                          _SchoolSwitcherButton(memberships: widget.schoolSession.memberships, onSelected: _switchSchool),
                        const SizedBox(width: 8),
                        NotificationsBell(membership: widget.membership),
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          onPressed: _openSyncCenter,
                          icon: const Icon(Icons.cloud_sync_outlined, size: 18),
                          label: Text(_pendingSyncCount == 0 ? 'Synced' : '$_pendingSyncCount pending'),
                        ),
                        const SizedBox(width: 12),
                        const CircleAvatar(child: Text('AY')),
                        if (constraints.maxWidth >= 1080) ...[
                          const SizedBox(width: 8),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(teacherName, style: TextStyle(fontWeight: FontWeight.w800)),
                              Text(teacherTitle, style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(child: _content()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(String key) => switch (key) {
        'dashboard' => Icons.dashboard_rounded,
        'timetable' => Icons.calendar_month_outlined,
        'classes' => Icons.class_outlined,
        'attendance' => Icons.fact_check_outlined,
        'lesson-plans' => Icons.description_outlined,
        'weekly-progress' => Icons.update_rounded,
        'syllabus' => Icons.menu_book_outlined,
        'assignments' => Icons.assignment_outlined,
        'assessments' => Icons.grading_outlined,
        'cbt' => Icons.computer_rounded,
        'learning-progress' => Icons.trending_up_rounded,
        'students' => Icons.groups_rounded,
        'messages' => Icons.forum_outlined,
        'ai' => Icons.auto_awesome_rounded,
        'performance' => Icons.insights_rounded,
        'profile' => Icons.person_outline_rounded,
        _ => Icons.circle_outlined,
      };
}

class _SchoolSwitcherButton extends StatelessWidget {
  const _SchoolSwitcherButton({required this.memberships, required this.onSelected});

  final List<SchoolMembership> memberships;
  final ValueChanged<SchoolMembership> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<SchoolMembership>(
        tooltip: 'Switch school',
        onSelected: onSelected,
        icon: const Icon(Icons.swap_horiz_rounded),
        itemBuilder: (_) => [
          for (final membership in memberships)
            PopupMenuItem(
              value: membership,
              child: Text('${membership.schoolName} · ${membership.roleLabel}'),
            ),
        ],
      );
}

import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';

class PracticeQuestion {
  const PracticeQuestion(
    this.prompt,
    this.options,
    this.correct,
    this.explanation,
  );
  final String prompt;
  final List<String> options;
  final int correct;
  final String explanation;
}

const studentPracticeQuestions = [
  PracticeQuestion(
    'What is 25% of 80?',
    ['10', '20', '25', '40'],
    1,
    'A quarter of 80 is 20.',
  ),
  PracticeQuestion(
    'Solve: 3x + 4 = 19.',
    ['3', '4', '5', '6'],
    2,
    'Subtract 4, then divide 15 by 3.',
  ),
  PracticeQuestion(
    'What is the area of a rectangle 8 cm long and 5 cm wide?',
    ['13 cm²', '26 cm²', '40 cm²', '80 cm²'],
    2,
    'Area = length × width = 8 × 5 = 40 cm².',
  ),
  PracticeQuestion(
    'Which fraction equals 0.5?',
    ['1/4', '1/2', '2/3', '3/4'],
    1,
    'One half is 0.5.',
  ),
  PracticeQuestion(
    'Find the mean of 4, 6 and 8.',
    ['4', '5', '6', '8'],
    2,
    'The total is 18; divide by 3 to get 6.',
  ),
];

class StudentRepository {
  StudentRepository({
    required this.database,
    required this.session,
    required this.membership,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final LocalDatabase database;
  final SchoolSessionController session;
  final SchoolMembership membership;
  final DateTime Function() now;
  static const entityType = '_student_personal_workspace';
  static const canonicalProfileEntityType = 'student_class_link';

  void _check() {
    final active = session.requireActiveMembership();
    if (active.role != SchoolRole.student ||
        active.id != membership.id ||
        active.schoolId != membership.schoolId) {
      throw StateError('This workspace belongs to the signed-in student.');
    }
  }

  Future<Map<String, Object?>> load() async {
    _check();
    final record = await database.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: entityType,
      entityId: membership.id,
    );
    final canonical = await database.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: canonicalProfileEntityType,
      entityId: membership.id,
    );
    _check();
    return {
      ...Map<String, Object?>.from(record?.payload ?? {}),
      if (canonical != null)
        'canonicalProfile': Map<String, Object?>.from(canonical.payload),
    };
  }

  Future<void> _save(Map<String, Object?> state) async {
    _check();
    final personal = Map<String, Object?>.from(state)..remove('canonicalProfile');
    await database.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: entityType,
      entityId: membership.id,
      payload: personal,
    );
  }

  Future<void> startPractice() async {
    if (LocalDatabase.blockDemoSeeds) {
      throw StateError('Official exams are not connected yet.');
    }
    final state = await load();
    if (state['deadline'] != null) return;
    await _save({
      ...state,
      'deadline': now()
          .add(const Duration(minutes: 10))
          .toUtc()
          .toIso8601String(),
      'answers': List<int?>.filled(studentPracticeQuestions.length, null),
    });
  }

  Future<void> answer(int question, int option) async {
    final state = await load();
    if (LocalDatabase.blockDemoSeeds ||
        state['deadline'] == null ||
        state['submitted'] == true ||
        !now().isBefore(DateTime.parse(state['deadline']! as String))) {
      throw StateError('This practice attempt is not open for answers.');
    }
    if (question < 0 ||
        question >= studentPracticeQuestions.length ||
        option < 0 ||
        option >= studentPracticeQuestions[question].options.length) {
      throw ArgumentError('Invalid answer.');
    }
    final answers = List<int?>.from(state['answers']! as List);
    answers[question] = option;
    await _save({...state, 'answers': answers});
  }

  Future<void> submit() async {
    final state = await load();
    if (state['deadline'] == null) throw StateError('Start an attempt first.');
    if (state['submitted'] == true) return;
    final answers = List<int?>.from(state['answers']! as List);
    final score = [
      for (var i = 0; i < studentPracticeQuestions.length; i++)
        if (answers[i] == studentPracticeQuestions[i].correct) i,
    ].length;
    await _save({
      ...state,
      'submitted': true,
      'score': score,
      'submittedAt': now().toUtc().toIso8601String(),
    });
  }

  Future<void> saveTasks(List<Map<String, Object?>> tasks) async {
    final state = await load();
    await _save({...state, 'tasks': tasks});
  }
}

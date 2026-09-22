import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../awards/data/award_repository.dart';
import '../../awards/domain/award_models.dart';
import '../../events/data/event_repository.dart';
import '../../meals/data/meal_repository.dart';
import '../../meals/domain/meal_models.dart';
import '../../transport/data/transport_rider_assignment_repository.dart';
import '../domain/parent_school_life_models.dart';
import 'parent_children_repository.dart';

const _notRecorded = 'Not recorded yet';

class ParentSchoolLifeRepository {
  /// [localDatabase] is accepted for constructor consistency with every other Parent repository,
  /// even though this one only ever reads through the real repositories below and never touches the
  /// local database directly itself.
  ParentSchoolLifeRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required ParentChildrenRepository children,
    required EventRepository events,
    required MealRepository meals,
    required AwardRepository awards,
    required TransportRiderAssignmentRepository transport,
  })  : _schoolSession = schoolSession,
        _children = children,
        _events = events,
        _meals = meals,
        _awards = awards,
        _transport = transport;

  final SchoolSessionController _schoolSession;
  final ParentChildrenRepository _children;
  final EventRepository _events;
  final MealRepository _meals;
  final AwardRepository _awards;
  final TransportRiderAssignmentRepository _transport;

  /// Every section here reads a real source shared with another role's screen, never a fixed sample:
  /// [EventRepository] (the same school-wide events Proprietor manages), a real per-student transport
  /// assignment ([TransportRiderAssignmentRepository], the same record Administrator assigns), the real
  /// whole-school weekly menu ([MealRepository]), and real recognitions ([AwardRepository]) matched to
  /// a linked child by name, excluding internal-only drafts.
  ///
  /// Two sections stay honestly empty because no real per-student source exists for them yet:
  /// [ParentSchoolLifeSnapshot.activities] (Activities only tracks section-level programmes and an
  /// aggregate member count, never which specific student is enrolled) and
  /// [ParentSchoolLifeSnapshot.mealPlans] (Meals is one real whole-school weekly menu, not a per-child
  /// plan). See docs/BACKEND_INTEGRATION.md.
  Future<ParentSchoolLifeSnapshot> load() async {
    final membership = _requireParentMembership();
    final linked = (await _children.load()).children;

    final eventSnapshot = await _events.load();
    final events = [
      for (final event in eventSnapshot.events)
        if (event.isUpcoming)
          ParentSchoolLifeEvent(dateLabel: event.date, title: event.title, scope: event.audience),
    ];

    final transport = <ParentSchoolLifeTransport>[];
    for (final child in linked) {
      final assignment = await _transport.assignmentForStudent(child.id);
      final assigned = assignment?.assigned ?? false;
      transport.add(ParentSchoolLifeTransport(
        childName: child.name,
        serviceCode: assigned ? assignment!.routeId : _notRecorded,
        status: assigned ? 'Active' : 'Not assigned',
        guardianSafeSummary: 'Pickup details restricted to authorized family account',
      ));
    }

    final mealSnapshot = await _meals.load();
    final todayName = _weekdayName(DateTime.now());
    SchoolMealDay? today;
    for (final day in mealSnapshot.meals) {
      if (day.day == todayName) {
        today = day;
        break;
      }
    }
    final todayMeal =
        today == null ? _notRecorded : '${today.breakfast} · ${today.lunch} · ${today.snack}';
    final todayMealService = today?.status.label ?? _notRecorded;

    final awardSnapshot = await _awards.load();
    final recognition = <ParentSchoolLifeRecognition>[
      for (final child in linked)
        for (final award in awardSnapshot.awards)
          if (award.recipientType == AwardRecipientType.student &&
              award.visibility != AwardVisibility.internalOnly &&
              _sameName(award.recipient, child.name))
            ParentSchoolLifeRecognition(
              childName: child.name,
              title: award.title,
              periodLabel: award.date,
            ),
    ];

    return ParentSchoolLifeSnapshot(
      familyAccountId: membership.id,
      activities: const [],
      events: events,
      transport: transport,
      mealPlans: const [],
      todayMeal: todayMeal,
      todayMealService: todayMealService,
      recognition: recognition,
    );
  }

  SchoolMembership _requireParentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.parent) {
      throw StateError('School Life requires an active Parent membership.');
    }
    return membership;
  }
}

bool _sameName(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();

String _weekdayName(DateTime dateTime) => const {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
    }[dateTime.weekday] ??
    '';

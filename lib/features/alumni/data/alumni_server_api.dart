import 'package:flutter/widgets.dart';

import '../../../core/network/api_client.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/alumni_directory_models.dart';
import '../domain/alumni_event_models.dart';
import '../domain/alumni_opportunity_models.dart';
import '../domain/alumni_pledge_models.dart';
import '../domain/alumni_profile_models.dart';

class AlumniServerApi {
  AlumniServerApi({
    required ApiClient api,
    required SchoolSessionController schoolSession,
  })  : _api = api,
        _schoolSession = schoolSession;

  final ApiClient _api;
  final SchoolSessionController _schoolSession;

  SchoolMembership get activeMembership =>
      _schoolSession.requireActiveMembership();

  Map<String, String> _who(SchoolMembership membership) =>
      {'membership': membership.id};

  Future<AlumniProfileRecord?> loadMyProfile(
    SchoolMembership membership,
  ) async {
    final data = await _api.get(
      'alumni/schools/${membership.schoolId}/me/',
      query: _who(membership),
    );
    if (data is! Map || data['profile'] == null) return null;
    return AlumniProfileRecord.fromJson(
      Map<String, dynamic>.from(data['profile'] as Map),
    );
  }

  Future<AlumniProfileRecord> saveMyProfile(
    SchoolMembership membership, {
    required String originalStudentReference,
    required String admissionNumber,
    required int? graduationYear,
    required String graduationSet,
    required String profession,
    required String organisation,
    required String locationText,
    required String bio,
    required bool directoryVisible,
  }) async {
    final data = await _api.put(
      'alumni/schools/${membership.schoolId}/me/',
      query: _who(membership),
      body: {
        'original_student_reference': originalStudentReference.trim(),
        'admission_number': admissionNumber.trim(),
        'graduation_year': graduationYear,
        'graduation_set': graduationSet.trim(),
        'profession': profession.trim(),
        'organisation': organisation.trim(),
        'location_text': locationText.trim(),
        'bio': bio.trim(),
        'directory_visible': directoryVisible,
      },
    );
    return _profileFromEnvelope(data);
  }

  /// Every real, verified, directory-visible alumnus of this school - a deliberately narrow,
  /// public-facing subset of their profile (see `AlumniDirectoryEntrySerializer`).
  Future<List<AlumniDirectoryEntry>> loadDirectory(
    SchoolMembership membership, {
    String query = '',
    int? graduationYear,
  }) async {
    final data = await _api.get(
      'alumni/schools/${membership.schoolId}/directory/',
      query: {
        ..._who(membership),
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (graduationYear != null) 'graduationYear': '$graduationYear',
      },
    );
    final map = Map<String, dynamic>.from(data as Map);
    return [
      for (final item in (map['entries'] as List? ?? const []))
        AlumniDirectoryEntry.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }

  /// Every real reunion/event this school has created for its Alumni, with this alumnus's own
  /// real RSVP state and the event's real attending count.
  Future<List<AlumniEvent>> loadEvents(SchoolMembership membership) async {
    final data = await _api.get(
      'alumni/schools/${membership.schoolId}/events/',
      query: _who(membership),
    );
    final map = Map<String, dynamic>.from(data as Map);
    return [
      for (final item in (map['events'] as List? ?? const []))
        AlumniEvent.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }

  /// Records this alumnus's own real RSVP - an updatable current answer, not an append-only
  /// receipt, since a person may genuinely change their mind about attending.
  Future<AlumniEvent> rsvp(
    SchoolMembership membership,
    String eventId, {
    required bool attending,
  }) async {
    final data = await _api.post(
      'alumni/schools/${membership.schoolId}/events/$eventId/rsvp/',
      query: _who(membership),
      body: {'attending': attending},
    );
    final map = Map<String, dynamic>.from(data as Map);
    return AlumniEvent.fromJson(Map<String, dynamic>.from(map['event'] as Map));
  }

  /// School management creates a real reunion/event - alumni browse and RSVP, they do not
  /// propose their own.
  Future<AlumniEvent> createEvent(
    SchoolMembership manager, {
    required String title,
    required String date,
    String timeText = '',
    String venue = '',
    String note = '',
  }) async {
    final data = await _api.post(
      'alumni/schools/${manager.schoolId}/events/',
      query: _who(manager),
      body: {
        'title': title.trim(),
        'date': date.trim(),
        'timeText': timeText.trim(),
        'venue': venue.trim(),
        'note': note.trim(),
      },
    );
    final map = Map<String, dynamic>.from(data as Map);
    return AlumniEvent.fromJson(Map<String, dynamic>.from(map['event'] as Map));
  }

  Future<AlumniManagementSnapshot> loadManagement(
    SchoolMembership manager, {
    String status = 'all',
  }) async {
    final data = await _api.get(
      'alumni/schools/${manager.schoolId}/management/',
      query: {..._who(manager), 'status': status},
    );
    final map = Map<String, dynamic>.from(data as Map);
    return AlumniManagementSnapshot(
      profiles: [
        for (final item in (map['profiles'] as List? ?? const []))
          AlumniProfileRecord.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      transitionCandidates: [
        for (final item in
            (map['transitionCandidates'] as List? ?? const []))
          AlumniTransitionCandidate.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
      ],
      pledges: [
        for (final item in (map['pledges'] as List? ?? const []))
          AlumniPledge.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      opportunities: [
        for (final item in (map['opportunities'] as List? ?? const []))
          AlumniOpportunity.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
    );
  }

  /// This alumnus's own real, non-monetary pledges - never a public board of everyone's.
  Future<List<AlumniPledge>> loadMyPledges(SchoolMembership membership) async {
    final data = await _api.get(
      'alumni/schools/${membership.schoolId}/give-back/',
      query: _who(membership),
    );
    final map = Map<String, dynamic>.from(data as Map);
    return [
      for (final item in (map['pledges'] as List? ?? const []))
        AlumniPledge.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }

  Future<AlumniPledge> createPledge(
    SchoolMembership membership, {
    required AlumniPledgeCategory category,
    required String description,
  }) async {
    final data = await _api.post(
      'alumni/schools/${membership.schoolId}/give-back/',
      query: _who(membership),
      body: {'category': category.name, 'description': description.trim()},
    );
    final map = Map<String, dynamic>.from(data as Map);
    return AlumniPledge.fromJson(Map<String, dynamic>.from(map['pledge'] as Map));
  }

  Future<AlumniPledge> withdrawPledge(SchoolMembership membership, String pledgeId) async {
    final data = await _api.post(
      'alumni/schools/${membership.schoolId}/give-back/$pledgeId/withdraw/',
      query: _who(membership),
    );
    final map = Map<String, dynamic>.from(data as Map);
    return AlumniPledge.fromJson(Map<String, dynamic>.from(map['pledge'] as Map));
  }

  /// School management moves a real pledge to `acknowledged` or `fulfilled` - never `withdrawn`,
  /// which stays the alumnus's own decision.
  Future<AlumniPledge> updatePledgeStatus(
    SchoolMembership manager,
    String pledgeId, {
    required AlumniPledgeStatus status,
    String schoolNote = '',
  }) async {
    final data = await _api.post(
      'alumni/schools/${manager.schoolId}/give-back/$pledgeId/status/',
      query: _who(manager),
      body: {'status': status.name, 'schoolNote': schoolNote.trim()},
    );
    final map = Map<String, dynamic>.from(data as Map);
    return AlumniPledge.fromJson(Map<String, dynamic>.from(map['pledge'] as Map));
  }

  Future<AlumniProfileRecord> transitionStudent(
    SchoolMembership manager, {
    required String studentMembershipId,
    required String originalStudentReference,
    required String admissionNumber,
    required int graduationYear,
    required String graduationSet,
  }) async {
    final data = await _api.post(
      'alumni/schools/${manager.schoolId}/management/transitions/',
      query: _who(manager),
      body: {
        'studentMembershipId': studentMembershipId,
        'originalStudentReference': originalStudentReference.trim(),
        'admissionNumber': admissionNumber.trim(),
        'graduationYear': graduationYear,
        'graduationSet': graduationSet.trim(),
      },
    );
    return _profileFromEnvelope(data);
  }

  Future<AlumniProfileRecord> verify(
    SchoolMembership manager,
    String alumniMembershipId, {
    String note = '',
  }) async {
    final data = await _api.post(
      'alumni/schools/${manager.schoolId}/management/$alumniMembershipId/verify/',
      query: _who(manager),
      body: {'note': note.trim()},
    );
    return _profileFromEnvelope(data);
  }

  Future<AlumniProfileRecord> reject(
    SchoolMembership manager,
    String alumniMembershipId, {
    required String note,
  }) async {
    final data = await _api.post(
      'alumni/schools/${manager.schoolId}/management/$alumniMembershipId/reject/',
      query: _who(manager),
      body: {'note': note.trim()},
    );
    return _profileFromEnvelope(data);
  }

  /// Every real job/opportunity posting for this school - a real posting board every real alumnus
  /// browses, not just their own.
  Future<List<AlumniOpportunity>> loadOpportunities(SchoolMembership membership) async {
    final data = await _api.get(
      'alumni/schools/${membership.schoolId}/opportunities/',
      query: _who(membership),
    );
    final map = Map<String, dynamic>.from(data as Map);
    return [
      for (final item in (map['opportunities'] as List? ?? const []))
        AlumniOpportunity.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }

  Future<AlumniOpportunity> postOpportunity(
    SchoolMembership membership, {
    required String title,
    required String organisation,
    required AlumniOpportunityType type,
    String locationText = '',
    required String description,
    String contactInfo = '',
  }) async {
    final data = await _api.post(
      'alumni/schools/${membership.schoolId}/opportunities/',
      query: _who(membership),
      body: {
        'title': title.trim(),
        'organisation': organisation.trim(),
        'opportunityType': type.wireValue,
        'locationText': locationText.trim(),
        'description': description.trim(),
        'contactInfo': contactInfo.trim(),
      },
    );
    final map = Map<String, dynamic>.from(data as Map);
    return AlumniOpportunity.fromJson(Map<String, dynamic>.from(map['opportunity'] as Map));
  }

  /// Closing follows the same "author or moderator" rule the server enforces - the real poster's
  /// own membership, or school management.
  Future<AlumniOpportunity> closeOpportunity(SchoolMembership membership, String opportunityId) async {
    final data = await _api.post(
      'alumni/schools/${membership.schoolId}/opportunities/$opportunityId/close/',
      query: _who(membership),
    );
    final map = Map<String, dynamic>.from(data as Map);
    return AlumniOpportunity.fromJson(Map<String, dynamic>.from(map['opportunity'] as Map));
  }

  AlumniProfileRecord _profileFromEnvelope(Object? data) {
    if (data is! Map || data['profile'] is! Map) {
      throw StateError('The server returned an invalid Alumni profile response.');
    }
    return AlumniProfileRecord.fromJson(
      Map<String, dynamic>.from(data['profile'] as Map),
    );
  }
}

class AlumniServerScope extends InheritedWidget {
  const AlumniServerScope({
    super.key,
    required this.api,
    required super.child,
  });

  final AlumniServerApi api;

  static AlumniServerApi? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AlumniServerScope>()?.api;

  @override
  bool updateShouldNotify(AlumniServerScope oldWidget) => api != oldWidget.api;
}

import 'package:flutter/widgets.dart';

import '../../../core/network/api_client.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
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
    );
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

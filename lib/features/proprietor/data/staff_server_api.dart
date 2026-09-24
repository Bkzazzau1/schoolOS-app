import 'package:flutter/widgets.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../shared/models/school_membership.dart';

class InvitationStatus {
  const InvitationStatus({
    required this.status,
    required this.linked,
    this.email,
    this.sentAt,
    this.expiresAt,
    this.acceptedAt,
    this.lastEvent,
    this.lastEventAt,
  });

  final String status;
  final bool linked;
  final String? email;
  final DateTime? sentAt;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final String? lastEvent;
  final DateTime? lastEventAt;

  bool get isPending => status == 'pending';
  bool get neverSent => isPending && sentAt == null;
  bool get deliveryFailed => lastEvent == 'failed';

  factory InvitationStatus.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) =>
        json[key] is String ? DateTime.parse(json[key] as String) : null;
    final event = json['lastEvent'] is Map
        ? Map<String, dynamic>.from(json['lastEvent'] as Map)
        : null;
    return InvitationStatus(
      status: json['status'] as String? ?? 'none',
      linked: json['linked'] as bool? ?? false,
      email: json['email'] as String?,
      sentAt: date('sentAt'),
      expiresAt: date('expiresAt'),
      acceptedAt: date('acceptedAt'),
      lastEvent: event?['event'] as String?,
      lastEventAt: event?['at'] is String
          ? DateTime.parse(event!['at'] as String)
          : null,
    );
  }
}

class OnboardingRequest {
  const OnboardingRequest({
    required this.staffId,
    required this.schoolName,
    required this.status,
    required this.email,
    required this.personal,
    required this.documents,
  });

  final String staffId;
  final String schoolName;
  final String status;
  final String email;
  final Map<String, Object?> personal;
  final List<({String name, String status})> documents;

  factory OnboardingRequest.fromJson(Map<String, dynamic> json) =>
      OnboardingRequest(
        staffId: json['staffId'] as String,
        schoolName: json['schoolName'] as String? ?? '',
        status: json['status'] as String? ?? '',
        email: json['email'] as String? ?? '',
        personal: Map<String, Object?>.from(
          (json['personal'] as Map?) ?? const {},
        ),
        documents: [
          for (final d in (json['documents'] as List? ?? const []))
            (name: (d as Map)['name'] as String, status: d['status'] as String),
        ],
      );
}

class CredentialParty {
  const CredentialParty({
    required this.name,
    required this.loginId,
    required this.requiresPasswordChange,
    this.temporaryPassword,
  });

  final String name;
  final String loginId;
  final bool requiresPasswordChange;
  final String? temporaryPassword;

  factory CredentialParty.fromJson(Map<String, dynamic> json) => CredentialParty(
        name: json['name'] as String? ?? '',
        loginId: json['loginId'] as String? ?? '',
        requiresPasswordChange:
            json['requiresPasswordChange'] as bool? ?? false,
        temporaryPassword: json['temporaryPassword'] as String?,
      );
}

class StudentCredentialHandoff {
  const StudentCredentialHandoff({
    required this.student,
    required this.parent,
    required this.temporaryPasswordRule,
  });

  final CredentialParty student;
  final CredentialParty parent;
  final String temporaryPasswordRule;

  factory StudentCredentialHandoff.fromJson(Map<String, dynamic> json) =>
      StudentCredentialHandoff(
        student: CredentialParty.fromJson(
          Map<String, dynamic>.from(json['student'] as Map),
        ),
        parent: CredentialParty.fromJson(
          Map<String, dynamic>.from(json['parent'] as Map),
        ),
        temporaryPasswordRule:
            json['temporaryPasswordRule'] as String? ?? 'first_name',
      );
}

class CredentialRecoveryItem {
  const CredentialRecoveryItem({
    required this.id,
    required this.name,
    required this.identityKind,
    required this.requestedIdentifier,
    required this.roles,
    required this.requestedAt,
  });

  final String id;
  final String name;
  final String identityKind;
  final String requestedIdentifier;
  final List<String> roles;
  final DateTime requestedAt;

  factory CredentialRecoveryItem.fromJson(Map<String, dynamic> json) =>
      CredentialRecoveryItem(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        identityKind: json['identityKind'] as String? ?? '',
        requestedIdentifier: json['requestedIdentifier'] as String? ?? '',
        roles: List<String>.from(json['roles'] as List? ?? const []),
        requestedAt: DateTime.parse(json['requestedAt'] as String),
      );
}

class StaffServerApi {
  StaffServerApi({required ApiClient api, this.afterChange}) : _api = api;

  final ApiClient _api;
  final Future<void> Function()? afterChange;

  Map<String, String> _who(SchoolMembership m) => {'membership': m.id};

  Future<String> approveProposal(
    SchoolMembership approver,
    String proposalId, {
    int? gross,
    int? deductions,
    String? systemRole,
  }) async {
    final data = await _api.post(
      'staff/schools/${approver.schoolId}/proposals/$proposalId/approve/',
      query: _who(approver),
      body: {
        if (gross != null) 'gross': gross,
        if (deductions != null) 'deductions': deductions,
        if (systemRole != null) 'systemRole': systemRole,
      },
    ) as Map;
    await afterChange?.call();
    return data['staffId'] as String;
  }

  Future<void> rejectProposal(
    SchoolMembership approver,
    String proposalId,
    String note,
  ) async {
    await _api.post(
      'staff/schools/${approver.schoolId}/proposals/$proposalId/reject/',
      query: _who(approver),
      body: {'note': note.trim()},
    );
    await afterChange?.call();
  }

  String _invitationPath(SchoolMembership owner, String staffId) =>
      'owner/schools/${owner.schoolId}/staff/$staffId/invitation/';

  Future<InvitationStatus> invitation(
    SchoolMembership member,
    String staffId,
  ) async {
    final data = await _api.get(
      _invitationPath(member, staffId),
      query: _who(member),
    );
    return InvitationStatus.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<InvitationStatus> resendInvitation(
    SchoolMembership member,
    String staffId, {
    String? email,
  }) async {
    final data = await _api.post(
      _invitationPath(member, staffId),
      query: _who(member),
      body: {
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      },
    );
    await afterChange?.call();
    return InvitationStatus.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> cancelInvitation(
    SchoolMembership owner,
    String staffId,
  ) async {
    await _api.delete(_invitationPath(owner, staffId), query: _who(owner));
  }

  Future<void> unlink(SchoolMembership owner, String staffId) async {
    await _api.post(
      'owner/schools/${owner.schoolId}/staff/$staffId/unlink/',
      query: _who(owner),
      body: const {},
    );
    await afterChange?.call();
  }

  Future<OnboardingRequest?> myOnboarding(SchoolMembership member) async {
    try {
      final data = await _api.get(
        'staff/me/onboarding/',
        query: _who(member),
      );
      return OnboardingRequest.fromJson(
        Map<String, dynamic>.from(data as Map),
      );
    } on ApiException catch (error) {
      if (error.code == 'no_open_request') return null;
      rethrow;
    }
  }

  Future<void> submitOnboarding(
    SchoolMembership member, {
    required Map<String, Object?> personal,
    required Map<String, Object?> payment,
    Map<String, String> documents = const {},
  }) async {
    await _api.post(
      'staff/me/onboarding/',
      query: _who(member),
      body: {
        'personal': personal,
        'payment': payment,
        'documents': documents,
      },
    );
    await afterChange?.call();
  }

  String _credentialPath(SchoolMembership member, String studentId) =>
      'schools/${member.schoolId}/students/$studentId/credentials/';

  Future<StudentCredentialHandoff> studentCredentials(
    SchoolMembership member,
    String studentId,
  ) async {
    final data = await _api.get(
      _credentialPath(member, studentId),
      query: _who(member),
    );
    return StudentCredentialHandoff.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  Future<StudentCredentialHandoff> resetStudentCredentials(
    SchoolMembership member,
    String studentId,
  ) async {
    final data = await _api.post(
      '${_credentialPath(member, studentId)}student/reset/',
      query: _who(member),
      body: const {},
    );
    await afterChange?.call();
    return StudentCredentialHandoff.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  Future<StudentCredentialHandoff> resetParentCredentials(
    SchoolMembership member,
    String studentId,
  ) async {
    final data = await _api.post(
      '${_credentialPath(member, studentId)}parent/reset/',
      query: _who(member),
      body: const {},
    );
    await afterChange?.call();
    return StudentCredentialHandoff.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  Future<StudentCredentialHandoff> changeParentPhone(
    SchoolMembership member,
    String studentId,
    String phone,
  ) async {
    final data = await _api.post(
      '${_credentialPath(member, studentId)}parent/phone/',
      query: _who(member),
      body: {'phone': phone.trim()},
    );
    await afterChange?.call();
    return StudentCredentialHandoff.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  Future<List<CredentialRecoveryItem>> credentialRecoveryRequests(
    SchoolMembership member,
  ) async {
    final data = await _api.get(
      'schools/${member.schoolId}/credentials/recovery/',
      query: _who(member),
    ) as Map;
    return [
      for (final item in (data['requests'] as List? ?? const []))
        CredentialRecoveryItem.fromJson(
          Map<String, dynamic>.from(item as Map),
        ),
    ];
  }

  Future<void> dismissCredentialRecovery(
    SchoolMembership member,
    String requestId,
  ) async {
    await _api.post(
      'schools/${member.schoolId}/credentials/recovery/$requestId/dismiss/',
      query: _who(member),
      body: const {},
    );
  }
}

class StaffServerScope extends InheritedWidget {
  const StaffServerScope({super.key, required this.api, required super.child});

  final StaffServerApi api;

  static StaffServerApi? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<StaffServerScope>()
      ?.api;

  @override
  bool updateShouldNotify(StaffServerScope oldWidget) => api != oldWidget.api;
}

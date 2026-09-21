import 'package:flutter/widgets.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../shared/models/school_membership.dart';

/// Where a staff member's invitation stands, as the owner sees it. Never the link itself.
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

  /// `none`, `pending`, `expired`, `accepted` or `revoked`.
  final String status;

  /// The person already has a login tied to this staff record.
  final bool linked;
  final String? email;
  final DateTime? sentAt;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;

  /// `created`, `sent`, `failed`, `previewed`, `accepted` or `revoked`.
  final String? lastEvent;
  final DateTime? lastEventAt;

  bool get isPending => status == 'pending';
  bool get neverSent => isPending && sentAt == null;
  bool get deliveryFailed => lastEvent == 'failed';

  factory InvitationStatus.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) => json[key] is String ? DateTime.parse(json[key] as String) : null;
    final event = json['lastEvent'] is Map ? Map<String, dynamic>.from(json['lastEvent'] as Map) : null;
    return InvitationStatus(
      status: json['status'] as String? ?? 'none',
      linked: json['linked'] as bool? ?? false,
      email: json['email'] as String?,
      sentAt: date('sentAt'),
      expiresAt: date('expiresAt'),
      acceptedAt: date('acceptedAt'),
      lastEvent: event?['event'] as String?,
      lastEventAt: event?['at'] is String ? DateTime.parse(event!['at'] as String) : null,
    );
  }
}

/// What the server holds about a staff member's own registration request.
class OnboardingRequest {
  const OnboardingRequest({required this.staffId, required this.schoolName, required this.status, required this.email, required this.personal, required this.documents});

  final String staffId;
  final String schoolName;
  final String status;
  final String email;
  final Map<String, Object?> personal;
  final List<({String name, String status})> documents;

  factory OnboardingRequest.fromJson(Map<String, dynamic> json) => OnboardingRequest(
        staffId: json['staffId'] as String,
        schoolName: json['schoolName'] as String? ?? '',
        status: json['status'] as String? ?? '',
        email: json['email'] as String? ?? '',
        personal: Map<String, Object?>.from((json['personal'] as Map?) ?? const {}),
        documents: [
          for (final d in (json['documents'] as List? ?? const []))
            (name: (d as Map)['name'] as String, status: d['status'] as String),
        ],
      );
}

/// The staff calls that must be decided by the server: approving and rejecting a
/// proposal, the invitation a staff member gets, and their own registration.
/// A refusal comes back as an `ApiException` with words fit to show.
class StaffServerApi {
  StaffServerApi({required ApiClient api, this.afterChange}) : _api = api;

  final ApiClient _api;

  /// Called after the server changed something the device also holds, so it can
  /// download the result. Awaited, so a screen can reload once it is here.
  final Future<void> Function()? afterChange;

  Map<String, String> _who(SchoolMembership m) => {'membership': m.id};

  /// Approves a proposal. Returns the new staff member's id.
  Future<String> approveProposal(SchoolMembership approver, String proposalId, {int? gross, int? deductions, String? systemRole}) async {
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

  Future<void> rejectProposal(SchoolMembership approver, String proposalId, String note) async {
    await _api.post(
      'staff/schools/${approver.schoolId}/proposals/$proposalId/reject/',
      query: _who(approver),
      body: {'note': note.trim()},
    );
    await afterChange?.call();
  }

  String _invitationPath(SchoolMembership owner, String staffId) =>
      'owner/schools/${owner.schoolId}/staff/$staffId/invitation/';

  Future<InvitationStatus> invitation(SchoolMembership member, String staffId) async {
    final data = await _api.get(_invitationPath(member, staffId), query: _who(member));
    return InvitationStatus.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Sends the invitation again (the old link stops working), optionally to a corrected email.
  Future<InvitationStatus> resendInvitation(SchoolMembership member, String staffId, {String? email}) async {
    final data = await _api.post(
      _invitationPath(member, staffId),
      query: _who(member),
      body: {if (email != null && email.trim().isNotEmpty) 'email': email.trim()},
    );
    await afterChange?.call();
    return InvitationStatus.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> cancelInvitation(SchoolMembership owner, String staffId) async {
    await _api.delete(_invitationPath(owner, staffId), query: _who(owner));
  }

  /// Ends the tie between a staff record and its login (the person left, or was linked to the wrong account).
  Future<void> unlink(SchoolMembership owner, String staffId) async {
    await _api.post('owner/schools/${owner.schoolId}/staff/$staffId/unlink/', query: _who(owner), body: const {});
    await afterChange?.call();
  }

  /// The signed-in staff member's own open registration request, or null if none is waiting.
  Future<OnboardingRequest?> myOnboarding(SchoolMembership member) async {
    try {
      final data = await _api.get('staff/me/onboarding/', query: _who(member));
      return OnboardingRequest.fromJson(Map<String, dynamic>.from(data as Map));
    } on ApiException catch (error) {
      if (error.code == 'no_open_request') return null;
      rethrow;
    }
  }

  /// Submits the registration. The server checks it with the same rules as everywhere else
  /// and answers at once, for example when a phone number or NIN already belongs to someone.
  Future<void> submitOnboarding(
    SchoolMembership member, {
    required Map<String, Object?> personal,
    required Map<String, Object?> payment,
    Map<String, String> documents = const {},
  }) async {
    await _api.post(
      'staff/me/onboarding/',
      query: _who(member),
      body: {'personal': personal, 'payment': payment, 'documents': documents},
    );
    await afterChange?.call();
  }
}

/// Makes the staff calls available to the screens. Absent on demo data.
class StaffServerScope extends InheritedWidget {
  const StaffServerScope({super.key, required this.api, required super.child});

  final StaffServerApi api;

  static StaffServerApi? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<StaffServerScope>()?.api;

  @override
  bool updateShouldNotify(StaffServerScope oldWidget) => api != oldWidget.api;
}

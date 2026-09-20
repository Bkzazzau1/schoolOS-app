class ParentAttendanceChildSummary {
  const ParentAttendanceChildSummary({
    required this.childId,
    required this.name,
    required this.className,
    required this.attendancePercent,
    required this.presentDays,
    required this.totalSchoolDays,
    required this.lateArrivals,
    required this.latestCheckInLabel,
    required this.captureDevice,
    required this.checkedInToday,
  });

  final String childId;
  final String name;
  final String className;
  final int attendancePercent;
  final int presentDays;
  final int totalSchoolDays;
  final int lateArrivals;
  final String latestCheckInLabel;
  final String captureDevice;
  final bool checkedInToday;

  String get presentDaysLabel => '$presentDays / $totalSchoolDays';

  Map<String, Object?> toJson() => {
        'childId': childId,
        'name': name,
        'className': className,
        'attendancePercent': attendancePercent,
        'presentDays': presentDays,
        'totalSchoolDays': totalSchoolDays,
        'lateArrivals': lateArrivals,
        'latestCheckInLabel': latestCheckInLabel,
        'captureDevice': captureDevice,
        'checkedInToday': checkedInToday,
      };

  factory ParentAttendanceChildSummary.fromJson(Map<String, dynamic> json) =>
      ParentAttendanceChildSummary(
        childId: json['childId'] as String,
        name: json['name'] as String,
        className: json['className'] as String,
        attendancePercent: (json['attendancePercent'] as num).toInt(),
        presentDays: (json['presentDays'] as num).toInt(),
        totalSchoolDays: (json['totalSchoolDays'] as num).toInt(),
        lateArrivals: (json['lateArrivals'] as num).toInt(),
        latestCheckInLabel: json['latestCheckInLabel'] as String,
        captureDevice: json['captureDevice'] as String,
        checkedInToday: json['checkedInToday'] as bool,
      );
}

class ParentAttendanceEvent {
  const ParentAttendanceEvent({
    required this.dateLabel,
    required this.childId,
    required this.childName,
    required this.checkIn,
    required this.checkOut,
    required this.gate,
    required this.captureMethod,
    required this.status,
  });

  final String dateLabel;
  final String childId;
  final String childName;
  final String checkIn;
  final String checkOut;
  final String gate;
  final String captureMethod;
  final String status;

  bool get isLate => status.toLowerCase() == 'late';
  String get captureLabel => '$gate · $captureMethod';

  Map<String, Object?> toJson() => {
        'dateLabel': dateLabel,
        'childId': childId,
        'childName': childName,
        'checkIn': checkIn,
        'checkOut': checkOut,
        'gate': gate,
        'captureMethod': captureMethod,
        'status': status,
      };

  factory ParentAttendanceEvent.fromJson(Map<String, dynamic> json) =>
      ParentAttendanceEvent(
        dateLabel: json['dateLabel'] as String,
        childId: json['childId'] as String,
        childName: json['childName'] as String,
        checkIn: json['checkIn'] as String,
        checkOut: json['checkOut'] as String,
        gate: json['gate'] as String,
        captureMethod: json['captureMethod'] as String,
        status: json['status'] as String,
      );
}

class ParentAttendanceNotification {
  const ParentAttendanceNotification({
    required this.title,
    required this.detail,
  });

  final String title;
  final String detail;

  Map<String, Object?> toJson() => {'title': title, 'detail': detail};

  factory ParentAttendanceNotification.fromJson(Map<String, dynamic> json) =>
      ParentAttendanceNotification(
        title: json['title'] as String,
        detail: json['detail'] as String,
      );
}

class ParentAttendanceSnapshot {
  const ParentAttendanceSnapshot({
    required this.familyAccountId,
    required this.children,
    required this.events,
    required this.notifications,
  });

  final String familyAccountId;
  final List<ParentAttendanceChildSummary> children;
  final List<ParentAttendanceEvent> events;
  final List<ParentAttendanceNotification> notifications;

  int get totalLateArrivals =>
      children.fold(0, (total, child) => total + child.lateArrivals);

  int get checkedInTodayCount =>
      children.where((child) => child.checkedInToday).length;

  Map<String, Object?> toJson() => {
        'familyAccountId': familyAccountId,
        'children': children.map((item) => item.toJson()).toList(),
        'events': events.map((item) => item.toJson()).toList(),
        'notifications': notifications.map((item) => item.toJson()).toList(),
      };

  factory ParentAttendanceSnapshot.fromJson(Map<String, dynamic> json) =>
      ParentAttendanceSnapshot(
        familyAccountId: json['familyAccountId'] as String,
        children: (json['children'] as List<dynamic>)
            .map(
              (item) => ParentAttendanceChildSummary.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
        events: (json['events'] as List<dynamic>)
            .map(
              (item) => ParentAttendanceEvent.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
        notifications: (json['notifications'] as List<dynamic>)
            .map(
              (item) => ParentAttendanceNotification.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
      );
}

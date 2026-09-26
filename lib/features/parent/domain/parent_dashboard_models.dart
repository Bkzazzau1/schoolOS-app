class ParentNavItem {
  const ParentNavItem({required this.key, required this.label});

  final String key;
  final String label;
}

class ParentChildSummary {
  const ParentChildSummary({
    required this.id,
    required this.name,
    required this.className,
    required this.section,
    required this.attendancePercent,
    required this.academicPercent,
    required this.feeBalance,
    required this.initials,
    required this.presentToday,
  });

  final String id;
  final String name;
  final String className;
  final String section;
  final int attendancePercent;
  final int academicPercent;
  final int feeBalance;
  final String initials;
  final bool presentToday;

  String get academicLabel => section == 'Primary' ? 'Learning' : 'Average';

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'className': className,
        'section': section,
        'attendancePercent': attendancePercent,
        'academicPercent': academicPercent,
        'feeBalance': feeBalance,
        'initials': initials,
        'presentToday': presentToday,
      };

  factory ParentChildSummary.fromJson(Map<String, dynamic> json) => ParentChildSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        className: json['className'] as String,
        section: json['section'] as String,
        attendancePercent: json['attendancePercent'] as int,
        academicPercent: json['academicPercent'] as int,
        feeBalance: json['feeBalance'] as int,
        initials: json['initials'] as String,
        presentToday: json['presentToday'] as bool,
      );
}

class ParentAttentionItem {
  const ParentAttentionItem({
    required this.title,
    required this.detail,
    required this.area,
    required this.destinationKey,
  });

  final String title;
  final String detail;
  final String area;
  final String destinationKey;

  Map<String, Object?> toJson() => {
        'title': title,
        'detail': detail,
        'area': area,
        'destinationKey': destinationKey,
      };

  factory ParentAttentionItem.fromJson(Map<String, dynamic> json) => ParentAttentionItem(
        title: json['title'] as String,
        detail: json['detail'] as String,
        area: json['area'] as String,
        destinationKey: json['destinationKey'] as String,
      );
}

/// What one child owes. Where the family pays is a single account for the whole family (see Parent Finance), never a
/// number per child.
class ParentChildBalance {
  const ParentChildBalance({
    required this.childName,
    required this.className,
    required this.balance,
  });

  final String childName;
  final String className;
  final int balance;

  Map<String, Object?> toJson() => {
        'childName': childName,
        'className': className,
        'balance': balance,
      };

  factory ParentChildBalance.fromJson(Map<String, dynamic> json) => ParentChildBalance(
        childName: json['childName'] as String,
        className: json['className'] as String? ?? '',
        balance: json['balance'] as int,
      );
}

class ParentFinanceSnapshot {
  const ParentFinanceSnapshot({
    required this.totalBilled,
    required this.totalPaid,
    required this.balances,
    required this.nextScheduledDebit,
    required this.nextScheduledDebitLabel,
  });

  final int totalBilled;
  final int totalPaid;
  final List<ParentChildBalance> balances;
  final int nextScheduledDebit;
  final String nextScheduledDebitLabel;

  int get balance => balances.fold(0, (sum, item) => sum + item.balance);

  Map<String, Object?> toJson() => {
        'totalBilled': totalBilled,
        'totalPaid': totalPaid,
        'balances': balances.map((item) => item.toJson()).toList(),
        'nextScheduledDebit': nextScheduledDebit,
        'nextScheduledDebitLabel': nextScheduledDebitLabel,
      };

  factory ParentFinanceSnapshot.fromJson(Map<String, dynamic> json) => ParentFinanceSnapshot(
        totalBilled: json['totalBilled'] as int,
        totalPaid: json['totalPaid'] as int,
        balances: (json['balances'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => ParentChildBalance.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(growable: false),
        nextScheduledDebit: json['nextScheduledDebit'] as int,
        nextScheduledDebitLabel: json['nextScheduledDebitLabel'] as String,
      );
}

class ParentMessagePreview {
  const ParentMessagePreview({
    required this.sender,
    required this.message,
    required this.timeLabel,
    required this.unread,
  });

  final String sender;
  final String message;
  final String timeLabel;
  final bool unread;

  Map<String, Object?> toJson() => {
        'sender': sender,
        'message': message,
        'timeLabel': timeLabel,
        'unread': unread,
      };

  factory ParentMessagePreview.fromJson(Map<String, dynamic> json) => ParentMessagePreview(
        sender: json['sender'] as String,
        message: json['message'] as String,
        timeLabel: json['timeLabel'] as String,
        unread: json['unread'] as bool,
      );
}

class ParentNoticePreview {
  const ParentNoticePreview({
    required this.title,
    required this.detail,
    required this.category,
  });

  final String title;
  final String detail;
  final String category;

  Map<String, Object?> toJson() => {
        'title': title,
        'detail': detail,
        'category': category,
      };

  factory ParentNoticePreview.fromJson(Map<String, dynamic> json) => ParentNoticePreview(
        title: json['title'] as String,
        detail: json['detail'] as String,
        category: json['category'] as String,
      );
}

class ParentDashboardSnapshot {
  const ParentDashboardSnapshot({
    required this.guardianName,
    required this.familyAccountId,
    required this.children,
    required this.attentionItems,
    required this.finance,
    required this.messages,
    required this.notices,
  });

  final String guardianName;
  final String familyAccountId;
  final List<ParentChildSummary> children;
  final List<ParentAttentionItem> attentionItems;
  final ParentFinanceSnapshot finance;
  final List<ParentMessagePreview> messages;
  final List<ParentNoticePreview> notices;

  int get linkedChildrenCount => children.length;
  int get presentTodayCount => children.where((child) => child.presentToday).length;
  int get unreadMessageCount => messages.where((message) => message.unread).length;
  int get totalCurrentBalance => finance.balance;

  Map<String, Object?> toJson() => {
        'guardianName': guardianName,
        'familyAccountId': familyAccountId,
        'children': children.map((child) => child.toJson()).toList(),
        'attentionItems': attentionItems.map((item) => item.toJson()).toList(),
        'finance': finance.toJson(),
        'messages': messages.map((message) => message.toJson()).toList(),
        'notices': notices.map((notice) => notice.toJson()).toList(),
      };

  factory ParentDashboardSnapshot.fromJson(Map<String, dynamic> json) => ParentDashboardSnapshot(
        guardianName: json['guardianName'] as String,
        familyAccountId: json['familyAccountId'] as String,
        children: (json['children'] as List<dynamic>)
            .map((item) => ParentChildSummary.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(growable: false),
        attentionItems: (json['attentionItems'] as List<dynamic>)
            .map((item) => ParentAttentionItem.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(growable: false),
        finance: ParentFinanceSnapshot.fromJson(
          Map<String, dynamic>.from(json['finance'] as Map),
        ),
        messages: (json['messages'] as List<dynamic>)
            .map((item) => ParentMessagePreview.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(growable: false),
        notices: (json['notices'] as List<dynamic>)
            .map((item) => ParentNoticePreview.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(growable: false),
      );
}

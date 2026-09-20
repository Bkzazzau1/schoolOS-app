enum ParentAttentionKind {
  attendance,
  finance,
  consent,
}

class ParentFamilyAccount {
  const ParentFamilyAccount({
    required this.familyId,
    required this.guardianName,
    required this.linkedChildren,
    required this.currentTermBalanceNaira,
    required this.nextScheduledDebitNaira,
    required this.nextScheduledDebitDate,
    required this.unreadMessages,
  });

  final String familyId;
  final String guardianName;
  final int linkedChildren;
  final int currentTermBalanceNaira;
  final int nextScheduledDebitNaira;
  final DateTime nextScheduledDebitDate;
  final int unreadMessages;

  Map<String, Object?> toJson() => {
        'familyId': familyId,
        'guardianName': guardianName,
        'linkedChildren': linkedChildren,
        'currentTermBalanceNaira': currentTermBalanceNaira,
        'nextScheduledDebitNaira': nextScheduledDebitNaira,
        'nextScheduledDebitDate': nextScheduledDebitDate.toIso8601String(),
        'unreadMessages': unreadMessages,
      };

  factory ParentFamilyAccount.fromJson(Map<String, dynamic> json) {
    return ParentFamilyAccount(
      familyId: json['familyId'] as String,
      guardianName: json['guardianName'] as String,
      linkedChildren: json['linkedChildren'] as int,
      currentTermBalanceNaira: json['currentTermBalanceNaira'] as int,
      nextScheduledDebitNaira: json['nextScheduledDebitNaira'] as int,
      nextScheduledDebitDate: DateTime.parse(json['nextScheduledDebitDate'] as String),
      unreadMessages: json['unreadMessages'] as int,
    );
  }
}

class ParentLinkedChild {
  const ParentLinkedChild({
    required this.id,
    required this.name,
    required this.className,
    required this.section,
    required this.attendancePercent,
    required this.academicPercent,
    required this.ledgerBalanceNaira,
    required this.initials,
    required this.presentToday,
    required this.allocationReference,
  });

  final String id;
  final String name;
  final String className;
  final String section;
  final int attendancePercent;
  final int academicPercent;
  final int ledgerBalanceNaira;
  final String initials;
  final bool presentToday;

  /// Reference used to allocate a family-account credit to this child's
  /// internal fee ledger. It is not a second family collection account.
  final String allocationReference;

  bool get isPrimary => section.toLowerCase() == 'primary';

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'className': className,
        'section': section,
        'attendancePercent': attendancePercent,
        'academicPercent': academicPercent,
        'ledgerBalanceNaira': ledgerBalanceNaira,
        'initials': initials,
        'presentToday': presentToday,
        'allocationReference': allocationReference,
      };

  factory ParentLinkedChild.fromJson(Map<String, dynamic> json) {
    return ParentLinkedChild(
      id: json['id'] as String,
      name: json['name'] as String,
      className: json['className'] as String,
      section: json['section'] as String,
      attendancePercent: json['attendancePercent'] as int,
      academicPercent: json['academicPercent'] as int,
      ledgerBalanceNaira: json['ledgerBalanceNaira'] as int,
      initials: json['initials'] as String,
      presentToday: json['presentToday'] as bool,
      allocationReference: json['allocationReference'] as String,
    );
  }
}

class ParentAttentionItem {
  const ParentAttentionItem({
    required this.kind,
    required this.title,
    required this.description,
    required this.meta,
  });

  final ParentAttentionKind kind;
  final String title;
  final String description;
  final String meta;

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'title': title,
        'description': description,
        'meta': meta,
      };

  factory ParentAttentionItem.fromJson(Map<String, dynamic> json) {
    return ParentAttentionItem(
      kind: ParentAttentionKind.values.byName(json['kind'] as String),
      title: json['title'] as String,
      description: json['description'] as String,
      meta: json['meta'] as String,
    );
  }
}

class ParentFinanceSnapshot {
  const ParentFinanceSnapshot({
    required this.totalBilledNaira,
    required this.totalPaidNaira,
    required this.balanceNaira,
  });

  final int totalBilledNaira;
  final int totalPaidNaira;
  final int balanceNaira;

  Map<String, Object?> toJson() => {
        'totalBilledNaira': totalBilledNaira,
        'totalPaidNaira': totalPaidNaira,
        'balanceNaira': balanceNaira,
      };

  factory ParentFinanceSnapshot.fromJson(Map<String, dynamic> json) {
    return ParentFinanceSnapshot(
      totalBilledNaira: json['totalBilledNaira'] as int,
      totalPaidNaira: json['totalPaidNaira'] as int,
      balanceNaira: json['balanceNaira'] as int,
    );
  }
}

class ParentMessagePreview {
  const ParentMessagePreview({
    required this.sender,
    required this.message,
    required this.whenLabel,
  });

  final String sender;
  final String message;
  final String whenLabel;

  Map<String, Object?> toJson() => {
        'sender': sender,
        'message': message,
        'whenLabel': whenLabel,
      };

  factory ParentMessagePreview.fromJson(Map<String, dynamic> json) {
    return ParentMessagePreview(
      sender: json['sender'] as String,
      message: json['message'] as String,
      whenLabel: json['whenLabel'] as String,
    );
  }
}

class ParentNoticePreview {
  const ParentNoticePreview({
    required this.title,
    required this.description,
    required this.category,
  });

  final String title;
  final String description;
  final String category;

  Map<String, Object?> toJson() => {
        'title': title,
        'description': description,
        'category': category,
      };

  factory ParentNoticePreview.fromJson(Map<String, dynamic> json) {
    return ParentNoticePreview(
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
    );
  }
}

class ParentDashboardSnapshot {
  const ParentDashboardSnapshot({
    required this.family,
    required this.children,
    required this.attentionItems,
    required this.finance,
    required this.messages,
    required this.notices,
    required this.aiPrompts,
  });

  final ParentFamilyAccount family;
  final List<ParentLinkedChild> children;
  final List<ParentAttentionItem> attentionItems;
  final ParentFinanceSnapshot finance;
  final List<ParentMessagePreview> messages;
  final List<ParentNoticePreview> notices;
  final List<String> aiPrompts;

  int get presentTodayCount => children.where((child) => child.presentToday).length;
  int get childLedgerBalanceTotalNaira => children.fold(0, (total, child) => total + child.ledgerBalanceNaira);

  void validate() {
    if (family.linkedChildren != children.length) {
      throw StateError('Family linked-child count does not match the linked child records.');
    }
    if (family.currentTermBalanceNaira != childLedgerBalanceTotalNaira) {
      throw StateError('Family balance must be derived from separate child ledgers.');
    }
    if (finance.balanceNaira != childLedgerBalanceTotalNaira) {
      throw StateError('Finance balance must reconcile to the sum of child ledger balances.');
    }
    if (finance.totalBilledNaira - finance.totalPaidNaira != finance.balanceNaira) {
      throw StateError('Family finance snapshot does not reconcile.');
    }
  }

  Map<String, Object?> toJson() => {
        'family': family.toJson(),
        'children': children.map((item) => item.toJson()).toList(growable: false),
        'attentionItems': attentionItems.map((item) => item.toJson()).toList(growable: false),
        'finance': finance.toJson(),
        'messages': messages.map((item) => item.toJson()).toList(growable: false),
        'notices': notices.map((item) => item.toJson()).toList(growable: false),
        'aiPrompts': aiPrompts,
      };

  factory ParentDashboardSnapshot.fromJson(Map<String, dynamic> json) {
    final snapshot = ParentDashboardSnapshot(
      family: ParentFamilyAccount.fromJson(Map<String, dynamic>.from(json['family'] as Map)),
      children: (json['children'] as List)
          .map((item) => ParentLinkedChild.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false),
      attentionItems: (json['attentionItems'] as List)
          .map((item) => ParentAttentionItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false),
      finance: ParentFinanceSnapshot.fromJson(Map<String, dynamic>.from(json['finance'] as Map)),
      messages: (json['messages'] as List)
          .map((item) => ParentMessagePreview.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false),
      notices: (json['notices'] as List)
          .map((item) => ParentNoticePreview.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false),
      aiPrompts: (json['aiPrompts'] as List).cast<String>(),
    );
    snapshot.validate();
    return snapshot;
  }
}

class ParentDashboardPermissions {
  const ParentDashboardPermissions({
    required this.canViewLinkedChildren,
    required this.canViewFamilyFinance,
    required this.canConfirmBankPayment,
    required this.canEditChildLedger,
    required this.canViewStaffPrivateNotes,
    required this.canViewRestrictedSafeguarding,
  });

  final bool canViewLinkedChildren;
  final bool canViewFamilyFinance;
  final bool canConfirmBankPayment;
  final bool canEditChildLedger;
  final bool canViewStaffPrivateNotes;
  final bool canViewRestrictedSafeguarding;
}

enum TeacherAiContext {
  jss2aMathematics,
  jss2bMathematics,
  jss3aMathematics,
  ss1aFurtherMathematics,
}

extension TeacherAiContextX on TeacherAiContext {
  String get label => switch (this) {
        TeacherAiContext.jss2aMathematics => 'JSS 2A · Mathematics',
        TeacherAiContext.jss2bMathematics => 'JSS 2B · Mathematics',
        TeacherAiContext.jss3aMathematics => 'JSS 3A · Mathematics',
        TeacherAiContext.ss1aFurtherMathematics => 'SS 1A · Further Mathematics',
      };

  String get className => label.split(' · ').first;
}

class TeacherAiPromptHistoryItem {
  const TeacherAiPromptHistoryItem({
    required this.id,
    required this.prompt,
    required this.context,
    required this.createdAt,
  });

  final String id;
  final String prompt;
  final TeacherAiContext context;
  final String createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'prompt': prompt,
        'context': context.name,
        'createdAt': createdAt,
      };

  factory TeacherAiPromptHistoryItem.fromJson(Map<String, dynamic> json) =>
      TeacherAiPromptHistoryItem(
        id: json['id'] as String,
        prompt: json['prompt'] as String,
        context: TeacherAiContext.values.byName(json['context'] as String),
        createdAt: json['createdAt'] as String,
      );
}

class TeacherAiTool {
  const TeacherAiTool({
    required this.title,
    required this.description,
    required this.destination,
  });

  final String title;
  final String description;
  final String destination;
}

class TeacherAiSuggestedAction {
  const TeacherAiSuggestedAction({
    required this.title,
    required this.description,
    required this.destination,
    required this.actionLabel,
  });

  final String title;
  final String description;
  final String destination;
  final String actionLabel;
}

class TeacherAiPermissions {
  const TeacherAiPermissions({
    required this.canUseAssignedClassContext,
    required this.canDraftTeachingContent,
    required this.canSuggestSupport,
    required this.canRetrieveUnrelatedClasses,
    required this.canAccessFinance,
    required this.canAccessStaffConfidentialData,
    required this.canAccessOtherSchools,
    required this.canAlterMarks,
    required this.canAlterAttendance,
    required this.canSendMessages,
    required this.canTakeConsequentialAction,
  });

  final bool canUseAssignedClassContext;
  final bool canDraftTeachingContent;
  final bool canSuggestSupport;
  final bool canRetrieveUnrelatedClasses;
  final bool canAccessFinance;
  final bool canAccessStaffConfidentialData;
  final bool canAccessOtherSchools;
  final bool canAlterMarks;
  final bool canAlterAttendance;
  final bool canSendMessages;
  final bool canTakeConsequentialAction;
}

const teacherAiGovernanceBoundary =
    'Teacher AI uses only teacher-authorized class context. It may plan, explain, analyze and draft, but it cannot alter marks or attendance, send communications, expose unrelated or confidential records, make safeguarding decisions, punish, promote, fail or exclude a learner, or treat a draft as approved school action.';

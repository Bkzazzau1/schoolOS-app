enum ProprietorAttentionTone { high, medium, info }

enum ProprietorLeadershipSignal { onTrack, review }

class ProprietorAttentionItem {
  const ProprietorAttentionItem({
    required this.title,
    required this.detail,
    required this.owner,
    required this.tone,
    this.moduleKey,
  });

  final String title;
  final String detail;
  final String owner;
  final ProprietorAttentionTone tone;

  /// The owner screen where this is dealt with.
  final String? moduleKey;
}

class ProprietorLeadershipItem {
  const ProprietorLeadershipItem({
    required this.name,
    required this.role,
    required this.scope,
    required this.signal,
  });

  final String name;
  final String role;
  final String scope;
  final ProprietorLeadershipSignal signal;

  String get signalLabel => switch (signal) {
        ProprietorLeadershipSignal.onTrack => 'On track',
        ProprietorLeadershipSignal.review => 'Review',
      };
}

class ProprietorKpi {
  const ProprietorKpi({
    required this.label,
    required this.value,
    required this.note,
    required this.trend,
    required this.tone,
  });

  final String label;
  final String value;
  final String note;
  final String trend;
  final ProprietorKpiTone tone;
}

enum ProprietorKpiTone { green, amber, blue, purple }

class ProprietorQuickAccessItem {
  const ProprietorQuickAccessItem({
    required this.title,
    required this.description,
    required this.moduleKey,
  });

  final String title;
  final String description;
  final String moduleKey;
}

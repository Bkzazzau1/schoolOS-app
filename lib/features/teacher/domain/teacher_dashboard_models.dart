class TeacherNavItem {
  const TeacherNavItem({required this.key, required this.label});

  final String key;
  final String label;
}

class TeacherKpi {
  const TeacherKpi({required this.label, required this.value, required this.hint});

  final String label;
  final String value;
  final String hint;
}

class TeacherClassSummary {
  const TeacherClassSummary({
    required this.name,
    required this.subject,
    required this.students,
    required this.nextLesson,
    required this.room,
    required this.progress,
  });

  final String name;
  final String subject;
  final int students;
  final String nextLesson;
  final String room;
  final int progress;

  Map<String, Object?> toJson() => {
        'name': name,
        'subject': subject,
        'students': students,
        'nextLesson': nextLesson,
        'room': room,
        'progress': progress,
      };

  factory TeacherClassSummary.fromJson(Map<String, dynamic> json) {
    return TeacherClassSummary(
      name: json['name'] as String,
      subject: json['subject'] as String,
      students: json['students'] as int,
      nextLesson: json['nextLesson'] as String,
      room: json['room'] as String,
      progress: json['progress'] as int,
    );
  }
}

class TeacherScheduleItem {
  const TeacherScheduleItem({
    required this.time,
    required this.className,
    required this.topic,
    required this.status,
  });

  final String time;
  final String className;
  final String topic;
  final String status;
}

class TeacherStudentReview {
  const TeacherStudentReview({
    required this.name,
    required this.className,
    required this.average,
    required this.attendance,
    required this.signal,
  });

  final String name;
  final String className;
  final int average;
  final int attendance;
  final String signal;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return '$name $className $signal'.toLowerCase().contains(normalized);
  }

  Map<String, Object?> toJson() => {
        'name': name,
        'className': className,
        'average': average,
        'attendance': attendance,
        'signal': signal,
      };

  factory TeacherStudentReview.fromJson(Map<String, dynamic> json) {
    return TeacherStudentReview(
      name: json['name'] as String,
      className: json['className'] as String,
      average: json['average'] as int,
      attendance: json['attendance'] as int,
      signal: json['signal'] as String,
    );
  }
}

class TeacherTask {
  const TeacherTask({
    required this.title,
    required this.meta,
    required this.tone,
    required this.destination,
  });

  final String title;
  final String meta;
  final String tone;
  final String destination;
}

class TeacherPerformanceMetric {
  const TeacherPerformanceMetric({required this.label, required this.value});

  final String label;
  final int value;
}

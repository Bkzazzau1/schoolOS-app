import '../domain/principal_timetable_models.dart';

const principalTimetableLessons = <PrincipalTimetableLesson>[
  PrincipalTimetableLesson(id: 'TT-101', day: 'Monday', time: '8:00 - 8:40', className: 'JSS 2A', subject: 'Mathematics', teacher: 'Mrs. Amina Yusuf', room: 'B12', status: PrincipalTimetableStatus.scheduled),
  PrincipalTimetableLesson(id: 'TT-102', day: 'Monday', time: '8:00 - 8:40', className: 'JSS 2B', subject: 'English Language', teacher: 'Mrs. Fatima Bello', room: 'B14', status: PrincipalTimetableStatus.scheduled),
  PrincipalTimetableLesson(id: 'TT-103', day: 'Monday', time: '8:40 - 9:20', className: 'JSS 3A', subject: 'Basic Science', teacher: 'Mr. Peter James', room: 'C04', status: PrincipalTimetableStatus.substitution),
  PrincipalTimetableLesson(id: 'TT-104', day: 'Monday', time: '9:20 - 10:00', className: 'SS 1A', subject: 'Physics', teacher: 'Unassigned', room: 'Lab 2', status: PrincipalTimetableStatus.uncovered),
  PrincipalTimetableLesson(id: 'TT-105', day: 'Monday', time: '10:20 - 11:00', className: 'JSS 2A', subject: 'English Language', teacher: 'Mrs. Fatima Bello', room: 'B12', status: PrincipalTimetableStatus.scheduled),
  PrincipalTimetableLesson(id: 'TT-106', day: 'Monday', time: '10:20 - 11:00', className: 'SS 1A', subject: 'English Language', teacher: 'Mrs. Fatima Bello', room: 'D06', status: PrincipalTimetableStatus.clash),
  PrincipalTimetableLesson(id: 'TT-107', day: 'Tuesday', time: '8:00 - 8:40', className: 'JSS 2A', subject: 'Basic Science', teacher: 'Mr. Peter James', room: 'B12', status: PrincipalTimetableStatus.scheduled),
  PrincipalTimetableLesson(id: 'TT-108', day: 'Tuesday', time: '8:40 - 9:20', className: 'JSS 2B', subject: 'Mathematics', teacher: 'Mrs. Amina Yusuf', room: 'B14', status: PrincipalTimetableStatus.scheduled),
  PrincipalTimetableLesson(id: 'TT-109', day: 'Wednesday', time: '9:20 - 10:00', className: 'JSS 3A', subject: 'Mathematics', teacher: 'Mr. Daniel John', room: 'C04', status: PrincipalTimetableStatus.scheduled),
  PrincipalTimetableLesson(id: 'TT-110', day: 'Thursday', time: '11:00 - 11:40', className: 'SS 2A', subject: 'Civic Education', teacher: 'Mrs. Grace Musa', room: 'D08', status: PrincipalTimetableStatus.scheduled),
  PrincipalTimetableLesson(id: 'TT-111', day: 'Friday', time: '8:00 - 8:40', className: 'SS 1A', subject: 'Further Mathematics', teacher: 'Mrs. Amina Yusuf', room: 'D06', status: PrincipalTimetableStatus.scheduled),
];

const principalTeacherLoads = <PrincipalTeacherLoad>[
  PrincipalTeacherLoad(name: 'Mrs. Amina Yusuf', lessons: 24, target: 22, status: 'Heavy'),
  PrincipalTeacherLoad(name: 'Mr. Daniel John', lessons: 19, target: 22, status: 'Balanced'),
  PrincipalTeacherLoad(name: 'Mrs. Fatima Bello', lessons: 26, target: 22, status: 'Heavy'),
  PrincipalTeacherLoad(name: 'Mr. Peter James', lessons: 21, target: 22, status: 'Balanced'),
  PrincipalTeacherLoad(name: 'Mrs. Grace Musa', lessons: 17, target: 22, status: 'Light'),
];

const principalRoomUtilization = <PrincipalRoomUtilization>[
  PrincipalRoomUtilization(room: 'B12', lessons: 31, utilization: 86),
  PrincipalRoomUtilization(room: 'B14', lessons: 29, utilization: 81),
  PrincipalRoomUtilization(room: 'C04', lessons: 27, utilization: 75),
  PrincipalRoomUtilization(room: 'D06', lessons: 24, utilization: 67),
  PrincipalRoomUtilization(room: 'Lab 2', lessons: 18, utilization: 50),
];

const principalTimetableDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
const principalTimetableStatuses = ['All statuses', 'Scheduled', 'Substitution', 'Uncovered', 'Clash'];

const principalTimetableLessonsThisWeek = 186;
const principalTimetableTodayLessons = 38;

const principalTimetableAiInsight =
    'The current prototype schedule has one uncovered Physics lesson and one teacher clash involving English Language. Mrs. Amina Yusuf and Mrs. Fatima Bello are also above the weekly teaching-load target, so substitutions should avoid adding more lessons to them where possible.';

import '../shared/models/school_membership.dart';

/// The sample people the demo signs in as. Each is a person with a role at a school; the demo
/// login offers all of them, so you can sign in as the owner, change something, then switch to
/// the person it affects and see it.
///
/// BrightGate Academy is the main school: it has an owner, a principal, an administrator, a
/// finance officer, teachers, support staff, a driver, a parent and a student.
const demoMemberships = <SchoolMembership>[
  SchoolMembership(id: 'membership-proprietor-001', schoolId: 'school-brightgate', schoolName: 'BrightGate Academy', role: SchoolRole.proprietor),
  SchoolMembership(id: 'membership-administrator-001', schoolId: 'school-brightgate', schoolName: 'BrightGate Academy', role: SchoolRole.administrator),
  SchoolMembership(id: 'membership-finance-001', schoolId: 'school-brightgate', schoolName: 'BrightGate Academy', role: SchoolRole.accountant),
  SchoolMembership(id: 'membership-principal-001', schoolId: 'school-brightgate', schoolName: 'BrightGate Academy', role: SchoolRole.principal),
  SchoolMembership(id: 'membership-teacher-002', schoolId: 'school-brightgate', schoolName: 'BrightGate Academy', role: SchoolRole.teacher),
  SchoolMembership(id: 'membership-teacher-003', schoolId: 'school-brightgate', schoolName: 'BrightGate Academy', role: SchoolRole.teacher),
  SchoolMembership(id: 'membership-staff-001', schoolId: 'school-brightgate', schoolName: 'BrightGate Academy', role: SchoolRole.staff),
  SchoolMembership(id: 'membership-parent-001', schoolId: 'school-brightgate', schoolName: 'BrightGate Academy', role: SchoolRole.parent),
  SchoolMembership(id: 'membership-parent-002', schoolId: 'school-brightgate', schoolName: 'BrightGate Academy', role: SchoolRole.parent),
  SchoolMembership(id: 'membership-student-001', schoolId: 'school-brightgate', schoolName: 'BrightGate Academy', role: SchoolRole.student),
  SchoolMembership(id: 'membership-driver-001', schoolId: 'school-brightgate', schoolName: 'BrightGate Academy', role: SchoolRole.driver),
  // A second school, to show someone who works at two.
  SchoolMembership(id: 'membership-teacher-001', schoolId: 'school-al-hikma', schoolName: 'Al-Hikma Academy', role: SchoolRole.teacher),
];

/// Who each sample membership is.
const demoPersonNames = <String, String>{
  'membership-proprietor-001': 'Alhaji Ibrahim Bashir',
  'membership-administrator-001': 'Mrs. Fatima Bello',
  'membership-finance-001': 'Mr. Yusuf Abdullahi',
  'membership-principal-001': 'Mr. Ibrahim Danladi',
  'membership-teacher-002': 'Mrs. Grace Musa',
  'membership-teacher-003': 'Mr. Daniel John',
  'membership-staff-001': 'Mr. Peter James',
  'membership-parent-001': 'Mrs. Amina Yusuf',
  'membership-parent-002': 'Mr. Sani Kabir',
  'membership-student-001': 'Ahmed Yusuf',
  'membership-driver-001': 'Mr. Musa Abubakar',
  'membership-teacher-001': 'Mrs. Hauwa Sule',
};

/// Someone the owner can manage: a person, their main role, and how to reach them.
class DemoPerson {
  const DemoPerson({required this.id, required this.name, required this.role, required this.schoolId});

  final String id;
  final String name;
  final SchoolRole role;
  final String schoolId;

  String get email => '${name.toLowerCase().replaceAll(RegExp(r'[^a-z ]'), '').trim().replaceAll(' ', '.')}@school.ng';
}

/// The sample people at one school.
List<DemoPerson> demoPeopleAt(String schoolId) => [
      for (final m in demoMemberships)
        if (m.schoolId == schoolId)
          DemoPerson(id: m.id, name: demoPersonNames[m.id] ?? m.roleLabel, role: m.role, schoolId: schoolId),
    ];

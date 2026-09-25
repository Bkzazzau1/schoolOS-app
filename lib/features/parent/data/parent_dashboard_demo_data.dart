import '../domain/parent_dashboard_models.dart';

const parentNavigation = <ParentNavItem>[
  ParentNavItem(key: 'dashboard', label: 'Home'),
  ParentNavItem(key: 'children', label: 'My Children'),
  ParentNavItem(key: 'progress', label: 'Learning Progress'),
  ParentNavItem(key: 'weekly-learning', label: 'Weekly Learning'),
  ParentNavItem(key: 'assignments', label: 'Assignments'),
  ParentNavItem(key: 'attendance', label: 'Attendance'),
  ParentNavItem(key: 'finance', label: 'Finance & Payments'),
  ParentNavItem(key: 'messages', label: 'Messages'),
  ParentNavItem(key: 'discussions', label: 'School Discussions'),
  ParentNavItem(key: 'school-life', label: 'School Life'),
  ParentNavItem(key: 'documents', label: 'Documents & Consent'),
  ParentNavItem(key: 'ai', label: 'Parent AI'),
  ParentNavItem(key: 'transferverify', label: 'TransferVerify Case'),
];

const parentPrivacyBoundary =
    'Private family access. This guardian account can only access linked children and approved family records. Other families, staff-private notes and restricted safeguarding records are never exposed.';

import '../domain/visitor_models.dart';

const visitorWebsiteSeed = <VisitorRecord>[
  VisitorRecord(
    id: 'VIS-101',
    visitor: 'Mrs. Zainab Ahmed',
    organization: 'Parent / Guardian',
    purpose: 'Scheduled meeting',
    host: 'Primary Office',
    area: 'Primary reception',
    arrival: '9:10 AM',
    departure: '10:02 AM',
    status: VisitStatus.checkedOut,
    pass: 'V-101',
    note: 'Scheduled guardian meeting; normal checkout completed.',
  ),
  VisitorRecord(
    id: 'VIS-102',
    visitor: 'Mr. Samuel Okoro',
    organization: 'EduTech Services',
    purpose: 'ICT maintenance',
    host: 'ICT Department',
    area: 'ICT Lab',
    arrival: '10:25 AM',
    departure: '—',
    status: VisitStatus.onCampus,
    pass: 'V-102',
    note: 'Vendor access limited to approved work area with staff host.',
  ),
  VisitorRecord(
    id: 'VIS-103',
    visitor: 'Dr. Mary James',
    organization: 'Guest speaker',
    purpose: 'Career talk',
    host: 'Principal Office',
    area: 'Assembly Hall',
    arrival: 'Expected 12:15 PM',
    departure: '—',
    status: VisitStatus.expected,
    pass: 'Pre-reg',
    note: 'Pre-registered guest for Secondary programme.',
  ),
  VisitorRecord(
    id: 'VIS-104',
    visitor: 'Delivery Rider',
    organization: 'Courier',
    purpose: 'Package delivery',
    host: 'Front Office',
    area: 'Reception only',
    arrival: '11:05 AM',
    departure: '11:12 AM',
    status: VisitStatus.checkedOut,
    pass: 'Desk log',
    note: 'No student-area access required.',
  ),
];

const visitorAccessRules = <String, String>{
  'Host required':
      'Visitor access should be tied to an accountable staff office/person.',
  'Minimum data':
      'Collect only what the school needs for safety and operational accountability.',
  'Restricted log':
      'Visitor history should not be visible to ordinary students or general community users.',
};

const visitorPickupBoundary =
    'Authorized child pickup should later use its own relationship/authorization check. A generic visitor pass must not automatically authorize collection of a child.';

List<VisitorStat> visitorStats(List<VisitorRecord> visits) => [
      VisitorStat(
        'Visits today',
        '${visits.length}',
        'Representative UI records',
      ),
      VisitorStat(
        'On campus',
        '${visits.where((visit) => visit.status == VisitStatus.onCampus).length}',
        'Currently signed in',
      ),
      VisitorStat(
        'Expected',
        '${visits.where((visit) => visit.status == VisitStatus.expected).length}',
        'Pre-registered',
      ),
      VisitorStat(
        'Checked out',
        '${visits.where((visit) => visit.status == VisitStatus.checkedOut).length}',
        'Completed visits',
      ),
      const VisitorStat(
        'Unescorted exceptions',
        '0',
        'Prototype indicator',
      ),
    ];

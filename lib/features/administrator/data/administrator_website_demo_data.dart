import '../domain/administrator_website_models.dart';

const administratorWebsiteSeed = AdministratorWebsiteSettings(
  heroHeadline: 'A strong beginning. A confident future.',
  heroSupportingText:
      'Nursery, Primary and Secondary education in a caring, structured learning environment.',
  admissionsOpen: true,
  admissionSession: '2026/2027',
);

const administratorWebsiteDomain = 'brightgateacademy.ng';
const administratorWebsiteApplications = 131;
const administratorWebsitePublishedNotices = 8;
const administratorWebsiteLastUpdate = 'Today';

const administratorWebsiteKpis = <AdministratorWebsiteKpi>[
  AdministratorWebsiteKpi(
    label: 'Domain',
    value: administratorWebsiteDomain,
    detail: 'Branded school website',
  ),
  AdministratorWebsiteKpi(
    label: 'Admissions',
    value: 'Open',
    detail: '2026/2027 intake',
  ),
  AdministratorWebsiteKpi(
    label: 'Applications',
    value: '131',
    detail: 'From website',
  ),
  AdministratorWebsiteKpi(
    label: 'Published notices',
    value: '8',
    detail: 'Public website content',
  ),
  AdministratorWebsiteKpi(
    label: 'Last update',
    value: administratorWebsiteLastUpdate,
    detail: 'Prototype content state',
  ),
];

const administratorPublicWebsiteSections = <PublicWebsiteSection>[
  PublicWebsiteSection(
    title: 'About the school',
    description: 'Mission, values, leadership and school story.',
    status: 'Published',
  ),
  PublicWebsiteSection(
    title: 'Admissions',
    description: 'Admission process, requirements and online application.',
    status: 'Published',
  ),
  PublicWebsiteSection(
    title: 'School Life',
    description: 'Activities, approved gallery content and events.',
    status: 'Published',
  ),
  PublicWebsiteSection(
    title: 'News & Notices',
    description: 'Public announcements only.',
    status: 'Published',
  ),
  PublicWebsiteSection(
    title: 'Contact',
    description: 'Campus address, phone, email and enquiry form.',
    status: 'Published',
  ),
];

const administratorAdmissionFormRequirements = <AdmissionFormRequirement>[
  AdmissionFormRequirement(
    title: 'Child identity',
    description: 'Name, date of birth, gender and proposed section/class.',
    status: 'Required',
  ),
  AdmissionFormRequirement(
    title: 'Guardian details',
    description: 'Name, phone, email and address.',
    status: 'Required',
  ),
  AdmissionFormRequirement(
    title: 'Previous school',
    description: 'Optional for younger applicants; configurable by section.',
    status: 'Configurable',
  ),
  AdmissionFormRequirement(
    title: 'Documents',
    description: 'Birth certificate, previous school report and guardian ID.',
    status: 'Required by policy',
  ),
];

const administratorWebsiteBrandIdentity = <WebsiteBrandIdentity>[
  WebsiteBrandIdentity(label: 'Website name', value: 'BrightGate Academy'),
  WebsiteBrandIdentity(label: 'Domain', value: administratorWebsiteDomain),
  WebsiteBrandIdentity(label: 'Logo', value: 'BGA mark'),
  WebsiteBrandIdentity(label: 'Theme', value: 'School theme variables'),
];

const administratorWebsiteWhiteLabelPrinciple =
    'Parents, applicants and public visitors interact with BrightGate Academy. SchoolOS operates the management layer behind the school’s own brand.';

const administratorWebsitePreviewBoundary =
    'Public website preview belongs to the school web experience. The native app manages the same website settings but does not pretend to render the production public site.';

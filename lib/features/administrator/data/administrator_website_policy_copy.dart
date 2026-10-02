import '../domain/administrator_website_models.dart';

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

/// The website's own brand identity, built from the school's real name - no real domain, logo or
/// theme setting exists yet, so those show an honest "Not set yet" rather than an invented value.
List<WebsiteBrandIdentity> administratorWebsiteBrandIdentity(String schoolName) => [
      WebsiteBrandIdentity(label: 'Website name', value: schoolName),
      const WebsiteBrandIdentity(label: 'Domain', value: 'Not set yet'),
      const WebsiteBrandIdentity(label: 'Logo', value: 'Not set yet'),
      const WebsiteBrandIdentity(label: 'Theme', value: 'Not set yet'),
    ];

const administratorWebsiteWhiteLabelPrinciple =
    'Parents, applicants and public visitors interact with the school\'s own brand. SchoolOS operates the management layer behind it.';

const administratorWebsitePreviewBoundary =
    'Connect to the internet to preview the public school website.';

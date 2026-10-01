/// Static guidance copy for the Noticeboard sidebar - not data about this school, so it never needs a
/// real backend source. Real activity (notices) lives in [NoticeboardRepository] instead.
const noticeboardPublishingAuthority = [
  ('Proprietor', 'May publish whole-school and any authorized campus notice.'),
  ('Principal / Vice Principal', 'Secondary and delegated whole-school operational announcements.'),
  ('Headmistress / Headmaster', 'Primary notices within Primary scope.'),
  ('Head Teacher', 'Early Years notices within Early Years scope.'),
  ('Teachers', 'Class notices only when explicit class-publishing permission is enabled.'),
];
const noticeboardDeliveryChannels = [
  ('In-app / portal', 'Default noticeboard delivery with read state.'),
  ('SMS / WhatsApp / Email', 'Optional external delivery for configured schools and templates.'),
  ('Acknowledgement', 'Critical notices can require “I acknowledge” rather than relying only on read receipts.'),
];
const noticeboardBoundary = 'Noticeboard content is authoritative and permission-controlled. Community posts can be conversational and interactive without carrying official-instruction status.';

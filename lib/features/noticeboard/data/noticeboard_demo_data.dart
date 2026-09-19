import '../domain/noticeboard_models.dart';

final noticeboardSeedNotices = <NoticeboardNotice>[
  NoticeboardNotice(id:'NB-001',title:'School closes at 12:00 PM on Friday',body:'All academic sections will close at 12:00 PM on Friday for staff professional development. Transport and collection arrangements should follow the revised closing time.',author:'School Proprietor Office',role:'Proprietor',priority:NoticePriority.important,audience:NoticeAudience.wholeSchool,publishedLabel:'Today · 8:00 AM',expiresLabel:'Friday · 6:00 PM',acknowledgementRequired:true,readCount:921,totalRecipients:1084,pinned:true,createdAt:DateTime.utc(2026,9,19,8)),
  NoticeboardNotice(id:'NB-002',title:'JSS 3 mock examination timetable released',body:'The mock examination timetable is now available. Students and parents should review the schedule and report timetable conflicts through the Secondary office.',author:'Mr. Ibrahim Danladi',role:'Principal · Secondary',priority:NoticePriority.normal,audience:NoticeAudience.jss3,publishedLabel:'Yesterday · 3:30 PM',expiresLabel:'30 Sep 2026',acknowledgementRequired:false,readCount:148,totalRecipients:176,pinned:false,createdAt:DateTime.utc(2026,9,18,15,30)),
  NoticeboardNotice(id:'NB-003',title:'Reception A guardian meeting window',body:'Reception A families with open attendance or settling-in follow-ups may book a short meeting with the Early Years team on Tuesday morning.',author:'Mrs. Mary Daniel',role:'Head Teacher · Early Years',priority:NoticePriority.normal,audience:NoticeAudience.earlyYears,publishedLabel:'Yesterday · 11:15 AM',expiresLabel:'Tuesday · 12:00 PM',acknowledgementRequired:false,readCount:64,totalRecipients:84,pinned:false,createdAt:DateTime.utc(2026,9,18,11,15)),
  NoticeboardNotice(id:'NB-004',title:'Primary water interruption notice',body:'A short water-supply interruption is expected between 10:00 and 11:00 AM. The school has arranged backup water and classes will continue normally.',author:'Mrs. Hauwa Sule',role:'Headmistress · Primary',priority:NoticePriority.important,audience:NoticeAudience.primary,publishedLabel:'Today · 7:40 AM',expiresLabel:'Today · 1:00 PM',acknowledgementRequired:false,readCount:302,totalRecipients:386,pinned:true,createdAt:DateTime.utc(2026,9,19,7,40)),
];

const noticeboardAverageReadRate = 82;
const noticeboardScheduledCount = 3;
const noticeboardPublishingAuthority = [
  ('Proprietor','May publish whole-school and any authorized campus notice.'),
  ('Principal / Vice Principal','Secondary and delegated whole-school operational announcements.'),
  ('Headmistress / Headmaster','Primary notices within Primary scope.'),
  ('Head Teacher','Early Years notices within Early Years scope.'),
  ('Teachers','Class notices only when explicit class-publishing permission is enabled.'),
];
const noticeboardDeliveryChannels = [
  ('In-app / portal','Default noticeboard delivery with read state.'),
  ('SMS / WhatsApp / Email','Optional external delivery for configured schools and templates.'),
  ('Acknowledgement','Critical notices can require “I acknowledge” rather than relying only on read receipts.'),
];
const noticeboardBoundary = 'Noticeboard content is authoritative and permission-controlled. Community posts can be conversational and interactive without carrying official-instruction status.';
